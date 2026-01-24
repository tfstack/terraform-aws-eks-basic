# EBS Web Application Example

This example demonstrates how to use the EBS CSI Driver with a web application that has an EBS persistent volume attached. You'll learn how persistent storage works in Kubernetes and how data persists across pod restarts.

## What This Example Creates

1. **EKS Cluster** with EBS CSI Driver addon enabled
2. **PersistentVolumeClaim (PVC)** using the `gp3` EBS storage class
3. **Web Application Deployment** (nginx) with the EBS volume mounted
4. **Kubernetes Service** to expose the web application

## Features Demonstrated

- ✅ EBS CSI Driver integration
- ✅ Persistent volume provisioning
- ✅ Pod with persistent storage
- ✅ Web application serving content from EBS volume
- ✅ Data persistence across pod restarts

## Understanding EBS CSI Driver

The **EBS CSI Driver** is a Container Storage Interface (CSI) driver that allows Kubernetes to provision and manage Amazon Elastic Block Store (EBS) volumes. When you create a PersistentVolumeClaim, the EBS CSI Driver automatically:

- Creates an EBS volume in AWS
- Attaches it to your EC2 node
- Mounts it into your pod
- Ensures data persists even if the pod is deleted

**Key Concepts:**

- **StorageClass**: Defines the "class" of storage (e.g., `gp3` for General Purpose SSD)
- **PersistentVolumeClaim (PVC)**: A request for storage by a user
- **PersistentVolume (PV)**: The actual EBS volume provisioned by the driver
- **Volume Binding Mode**: `WaitForFirstConsumer` means the volume is only created when a pod needs it

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.6.0
- kubectl installed
- AWS account with permissions to create EKS clusters and EBS volumes

## Step-by-Step Walkthrough

### Step 1: Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region   = "ap-southeast-2"
cluster_name = "ebs-web-app"
```

### Step 2: Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

Wait for the cluster and EBS CSI Driver to be fully provisioned (this may take 10-15 minutes).

**What happens during apply:**

- EKS cluster is created
- EBS CSI Driver addon is installed
- VPC and networking resources are created
- Worker nodes are provisioned

### Step 3: Configure kubectl

```bash
aws eks update-kubeconfig --name ebs-web-app --region ap-southeast-2
```

Verify you can connect:

```bash
kubectl get nodes
```

**Expected output:**

```plaintext
NAME                                          STATUS   ROLES    AGE   VERSION
ip-10-0-101-xxx.ap-southeast-2.compute.internal   Ready    <none>   5m    v1.34.x
ip-10-0-102-xxx.ap-southeast-2.compute.internal   Ready    <none>   5m    v1.34.x
```

### Step 4: Verify EBS CSI Driver

The EBS CSI Driver is automatically installed by Terraform. Verify it's running:

```bash
# Check EBS CSI Driver pods
kubectl get pods -n kube-system | grep ebs-csi

# Check StorageClass
kubectl get storageclass gp3
```

**Expected output:**

```plaintext
NAME   PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp3    ebs.csi.aws.com   Delete          WaitForFirstConsumer   true                   5m
```

**Key observation:**

- `VOLUMEBINDINGMODE: WaitForFirstConsumer` means the EBS volume won't be created until a pod is scheduled that needs it
- This is more efficient than creating volumes immediately

### Step 5: Verify Kubernetes Resources

The Terraform deployment automatically creates:

- **PersistentVolumeClaim** - Request for 10Gi of storage
- **Deployment** - Web application with nginx
- **Service** - ClusterIP service exposing the app

Check the resources:

```bash
# Check PVC status
kubectl get pvc web-app-storage

# Check deployment
kubectl get deployment web-app

# Check service
kubectl get service web-app

# Check pods
kubectl get pods -l app=web-app
```

**Expected output:**

```plaintext
NAME             STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
web-app-storage  Pending                                      gp3           2m

NAME       READY   UP-TO-DATE   AVAILABLE   AGE
web-app    0/1     1            0           2m

NAME      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
web-app   ClusterIP   172.20.xxx.xxx   <none>        80/TCP    2m
```

**Important note:**

- The PVC shows `STATUS: Pending` - this is **normal** with `WaitForFirstConsumer` mode
- The volume will be created when the pod is scheduled
- The deployment may show `0/1` initially while waiting for the volume

### Step 6: Wait for Pod to be Ready

The pod needs to:

1. Be scheduled on a node
2. Trigger EBS volume creation
3. Wait for volume attachment
4. Start the container

Watch the pod status:

```bash
kubectl get pods -l app=web-app -w
```

**Expected progression:**

```plaintext
NAME                      READY   STATUS              RESTARTS   AGE
web-app-xxxxx-xxxxx       0/1     Pending             0          10s
web-app-xxxxx-xxxxx       0/1     ContainerCreating   0          30s
web-app-xxxxx-xxxxx       1/1     Running             0          2m
```

Once the pod is `Running`, verify the PVC is now bound:

```bash
kubectl get pvc web-app-storage
```

**Expected output:**

```plaintext
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
web-app-storage  Bound    pvc-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx         10Gi       RWO            gp3           5m
```

**What happened:**

- Pod was scheduled → EBS CSI Driver created the volume → Volume attached to node → Pod started

### Step 7: Verify EBS Volume Details

Check the PersistentVolume that was created:

```bash
# List PersistentVolumes
kubectl get pv

# Describe the PVC to see volume details
kubectl describe pvc web-app-storage
```

**Expected output:**

```plaintext
Name:          web-app-storage
Namespace:     default
StorageClass:  gp3
Status:        Bound
Volume:        pvc-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx
Capacity:      10Gi
Access Modes:  RWO
VolumeMode:    Filesystem
```

Verify the volume is mounted in the pod:

```bash
# Check volume mount
kubectl describe pod -l app=web-app | grep -A 5 "Mounts:"

# Check disk usage
kubectl exec deployment/web-app -- df -h /usr/share/nginx/html
```

**Expected output:**

```plaintext
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme1n1     10G   24K   10G   1% /usr/share/nginx/html
```

### Step 8: Access the Web Application

The web application is now running and serving content from the EBS volume.

#### Option 1: Port Forward (Recommended for Testing)

```bash
# Port forward the service
kubectl port-forward service/web-app 8080:80
```

In another terminal or browser:

```bash
# Test with curl
curl http://localhost:8080

# Or open in browser
# http://localhost:8080
```

**Expected output:**

You should see an HTML page with:

- Title: "EBS Persistent Volume Demo"
- Message: "Success! This content is stored on an EBS volume."
- Information about the volume mount path

#### Option 2: Direct Pod Access

```bash
# Get pod name
POD_NAME=$(kubectl get pod -l app=web-app -o jsonpath='{.items[0].metadata.name}')

# Port forward to pod
kubectl port-forward pod/$POD_NAME 8080:80
```

### Step 9: Test Data Persistence

This is the key demonstration - proving that data persists across pod restarts.

#### Test 1: Create a file and verify it persists

```bash
# Create a test file on the persistent volume
kubectl exec deployment/web-app -- sh -c "echo 'This file persists!' > /usr/share/nginx/html/persistence-test.txt"

# Verify the file exists
kubectl exec deployment/web-app -- cat /usr/share/nginx/html/persistence-test.txt
```

**Expected output:**

```text
This file persists!
```

#### Test 2: Delete the pod and verify data remains

```bash
# Delete the pod (it will be recreated automatically)
kubectl delete pod -l app=web-app

# Wait for new pod to be ready
kubectl wait --for=condition=ready pod -l app=web-app --timeout=2m

# Verify the file still exists
kubectl exec deployment/web-app -- cat /usr/share/nginx/html/persistence-test.txt
```

**Expected output:**

```text
This file persists!
```

**What happened:**

- Old pod was deleted
- New pod was created
- EBS volume was reattached to the new pod
- **The file is still there!** ✅

#### Test 3: Modify content and verify

```bash
# Update the HTML content
kubectl exec deployment/web-app -- sh -c "echo '<h1>Data Persists!</h1>' > /usr/share/nginx/html/test.html"

# Access the new content
kubectl port-forward service/web-app 8080:80 &
curl http://localhost:8080/test.html
```

### Step 10: Verify EBS Volume in AWS Console

You can also verify the EBS volume was created in AWS:

```bash
# Get the volume ID from the PVC
VOLUME_ID=$(kubectl get pv -o jsonpath='{.items[?(@.spec.claimRef.name=="web-app-storage")].spec.csi.volumeHandle}' | cut -d'/' -f4)

# Describe the volume
aws ec2 describe-volumes --volume-ids $VOLUME_ID --query 'Volumes[0].{ID:VolumeId,Size:Size,Type:VolumeType,State:State}' --output table
```

**Expected output:**

```text
|      DescribeVolumes      |
+--------+------+-------+--------+
|   ID   | Size | State |  Type  |
+--------+------+-------+--------+
| vol-xxx|  10  | in-use|  gp3   |
+--------+------+-------+--------+
```

## Understanding the Components

### PersistentVolumeClaim

The PVC in `kubernetes.tf` requests:

- **10Gi** of storage
- **gp3** storage class (General Purpose SSD)
- **ReadWriteOnce** access mode (single pod can mount)

**Key configuration:**

```hcl
wait_until_bound = false
```

This is important because with `WaitForFirstConsumer` mode, the PVC won't bind until a pod is scheduled. Terraform shouldn't wait indefinitely.

### Deployment

The deployment includes:

- **Init container**: Populates the EBS volume with HTML content
- **Main container**: nginx serving content from the mounted volume
- **Volume mount**: `/usr/share/nginx/html` on the EBS volume

### Service

The ClusterIP service exposes the web application internally within the cluster.

## Configuration

### Required Variables

- `cluster_name`: Name of the EKS cluster (default: `ebs-web-app`)
- `aws_region`: AWS region for resources (default: `ap-southeast-2`)

### Optional Variables

- `cluster_version`: Kubernetes version (default: `1.34`)
- `node_instance_types`: EC2 instance types for nodes (default: `["t3.medium"]`)
- `node_desired_size`: Desired number of nodes (default: `2`)
- `node_min_size`: Minimum number of nodes (default: `1`)
- `node_max_size`: Maximum number of nodes (default: `3`)
- `node_disk_size`: Disk size in GiB (default: `20`)

## Storage Configuration

The example uses:

- **Storage Class**: `gp3` (default EBS storage class created by the module)
- **Volume Size**: 10Gi
- **Access Mode**: ReadWriteOnce (single pod can mount)
- **Volume Type**: gp3 (General Purpose SSD)
- **Binding Mode**: WaitForFirstConsumer (volume created when pod is scheduled)

## Cleanup

To remove all resources:

```bash
terraform destroy
```

This will delete:

- The EKS cluster
- The VPC and networking resources
- **The EBS volumes (data will be lost)**
- All Kubernetes resources

**Important:** Make sure to backup any important data before destroying!

## Troubleshooting

### Pod is in Pending state

If the pod is stuck in Pending state:

```bash
# Check pod events
kubectl describe pod -l app=web-app

# Check if PVC is bound
kubectl get pvc

# Check EBS CSI Driver pods
kubectl get pods -n kube-system | grep ebs-csi
```

**Common issues:**

- EBS CSI Driver not ready → Wait a few minutes
- No nodes available → Check node group status
- Volume attachment failed → Check EBS CSI Driver logs

### PVC is in Pending state

If the PVC is not bound:

1. **Verify EBS CSI Driver is installed:**

   ```bash
   kubectl get pods -n kube-system | grep ebs-csi
   ```

2. **Check storage class exists:**

   ```bash
   kubectl get storageclass gp3
   ```

3. **Check EBS CSI Driver logs:**

   ```bash
   kubectl logs -n kube-system -l app=ebs-csi-controller
   ```

4. **Verify IAM permissions:**
   The EBS CSI Driver needs IAM permissions to create volumes. The module automatically creates the required IAM role.

### Volume attachment issues

If the volume is created but not attached:

```bash
# Check volume attachment status
kubectl describe pv

# Check node events
kubectl get events --sort-by=.lastTimestamp | grep -i volume

# Check EBS CSI Driver node plugin
kubectl get pods -n kube-system | grep ebs-csi-node
```

## Next Steps

- **Scale the deployment** - Note: ReadWriteOnce volumes can only be mounted by one pod
- **Use ReadWriteMany storage** - Requires EFS CSI driver for multi-pod access
- **Add a Load Balancer** - Use AWS Load Balancer Controller to expose the app externally
- **Implement backup strategies** - Use AWS Backup or snapshot the EBS volumes
- **Monitor volume usage** - Set up CloudWatch alarms for volume metrics
- **Use different storage classes** - Try `io1` for high IOPS or `st1` for throughput-optimized

## Key Takeaways

1. **EBS CSI Driver** automatically provisions EBS volumes when you create a PVC
2. **WaitForFirstConsumer** mode delays volume creation until a pod needs it (more efficient)
3. **Data persists** across pod restarts because it's stored on EBS, not in the pod
4. **ReadWriteOnce** means only one pod can mount the volume at a time
5. **Terraform manages** the entire lifecycle - cluster, driver, and application

## References

- [EBS CSI Driver Documentation](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [AWS EBS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AmazonEBS.html)
