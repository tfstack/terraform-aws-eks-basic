apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: eks-capabilities-appstack.kro.run
spec:
  schema:
    apiVersion: v1alpha1
    kind: WebAppStack
    spec:
      name: string
      team: string
      image: string
      replicas: integer
      containerPort: integer
      bucket:
        enabled: boolean
        name: string
        region: string
      ingress:
        enabled: boolean
        annotations: object
    status:
      deploymentStatus: ${deployment.status.conditions}
      bucketStatus: ${s3Bucket.status.ackResourceMetadata.arn}
      serviceStatus: ${service.status}

  resources:
  # Kubernetes Deployment
  - id: deployment
    template:
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: ${schema.spec.name}
        labels:
          app: ${schema.spec.name}
          team: ${schema.spec.team}
      spec:
        replicas: ${schema.spec.replicas}
        selector:
          matchLabels:
            app: ${schema.spec.name}
        template:
          metadata:
            labels:
              app: ${schema.spec.name}
              team: ${schema.spec.team}
          spec:
            serviceAccountName: ${schema.spec.name}
            containers:
              - name: ${schema.spec.name}
                image: ${schema.spec.image}
                ports:
                  - containerPort: ${schema.spec.containerPort}
                    name: http
                env:
                  - name: AWS_REGION
                    value: "__AWS_REGION__"
                  - name: DYNAMODB_TABLE_NAME
                    value: ${schema.spec.name}
                resources:
                  requests:
                    cpu: "100m"
                    memory: "128Mi"
                  limits:
                    cpu: "500m"
                    memory: "256Mi"

  # Kubernetes Service
  - id: service
    template:
      apiVersion: v1
      kind: Service
      metadata:
        name: ${schema.spec.name}
        labels:
          app: ${schema.spec.name}
          team: ${schema.spec.team}
      spec:
        type: ClusterIP
        selector:
          app: ${schema.spec.name}
        ports:
          - port: 80
            targetPort: ${schema.spec.containerPort}
            protocol: TCP
            name: http

  # ServiceAccount for Pod Identity
  - id: serviceaccount
    template:
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: ${schema.spec.name}
        labels:
          app: ${schema.spec.name}
          team: ${schema.spec.team}

  # Pod Identity Association (ACK)
  - id: podidentity
    template:
      apiVersion: eks.services.k8s.aws/v1alpha1
      kind: PodIdentityAssociation
      metadata:
        name: ${schema.spec.name}
        namespace: ${schema.metadata.namespace}
        annotations:
          services.k8s.aws/skip-resource-tags: "true"
      spec:
        clusterName: "__CLUSTER_NAME__"
        namespace: ${schema.metadata.namespace}
        serviceAccount: ${schema.spec.name}
        roleARN: ${iamRole.status.ackResourceMetadata.arn}

  # IAM Role (ACK)
  - id: iamRole
    template:
      apiVersion: iam.services.k8s.aws/v1alpha1
      kind: Role
      metadata:
        name: ${schema.spec.name}-role
        namespace: ${schema.metadata.namespace}
      spec:
        name: ${schema.spec.name}-role
        assumeRolePolicyDocument: |
          {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Principal": {
                  "Service": "pods.eks.amazonaws.com"
                },
                "Action": [
                  "sts:AssumeRole",
                  "sts:TagSession"
                ]
              }
            ]
          }
        policies:
          - ${iamPolicy.status.ackResourceMetadata.arn}
        tags:
          - key: App
            value: ${schema.spec.name}
          - key: Team
            value: ${schema.spec.team}

  # IAM Policy for DynamoDB (ACK)
  - id: iamPolicy
    template:
      apiVersion: iam.services.k8s.aws/v1alpha1
      kind: Policy
      metadata:
        name: ${schema.spec.name}-policy
        namespace: ${schema.metadata.namespace}
      spec:
        name: ${schema.spec.name}-policy
        policyDocument: |
          {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Action": [
                  "dynamodb:PutItem",
                  "dynamodb:GetItem",
                  "dynamodb:UpdateItem",
                  "dynamodb:DeleteItem",
                  "dynamodb:Query",
                  "dynamodb:Scan"
                ],
                "Resource": "${dynamodbTable.status.ackResourceMetadata.arn}"
              }
            ]
          }
        tags:
          - key: App
            value: ${schema.spec.name}

  # DynamoDB Table (ACK)
  - id: dynamodbTable
    template:
      apiVersion: dynamodb.services.k8s.aws/v1alpha1
      kind: Table
      metadata:
        name: ${schema.spec.name}
        namespace: ${schema.metadata.namespace}
        labels:
          app: ${schema.spec.name}
          team: ${schema.spec.team}
      spec:
        tableName: ${schema.spec.name}
        attributeDefinitions:
          - attributeName: id
            attributeType: S
        keySchema:
          - attributeName: id
            keyType: HASH
        billingMode: PAY_PER_REQUEST
        tags:
          - key: App
            value: ${schema.spec.name}
          - key: Team
            value: ${schema.spec.team}

  # S3 Bucket (ACK) - Conditional
  - id: s3Bucket
    includeWhen:
      - ${schema.spec.bucket.enabled}
    template:
      apiVersion: s3.services.k8s.aws/v1alpha1
      kind: Bucket
      metadata:
        name: ${schema.spec.bucket.name}
        namespace: ${schema.metadata.namespace}
        labels:
          team: ${schema.spec.team}
      spec:
        name: ${schema.spec.bucket.name}
        createBucketConfiguration:
          locationConstraint: ${schema.spec.bucket.region}

  # Ingress (Conditional)
  - id: ingress
    includeWhen:
      - ${schema.spec.ingress.enabled}
    template:
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: ${schema.spec.name}-ingress
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: ip
      spec:
        ingressClassName: alb
        rules:
          - http:
              paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: ${schema.spec.name}
                      port:
                        number: 80

  # Pod Disruption Budget
  - id: pdb
    template:
      apiVersion: policy/v1
      kind: PodDisruptionBudget
      metadata:
        name: ${schema.spec.name}
        labels:
          app: ${schema.spec.name}
      spec:
        minAvailable: 1
        selector:
          matchLabels:
            app: ${schema.spec.name}
