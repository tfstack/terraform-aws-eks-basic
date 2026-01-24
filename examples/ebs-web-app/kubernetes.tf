# =============================================================================
# Web Application with EBS Persistent Volume
# This demonstrates the EBS CSI driver working with a web application
# =============================================================================

# PersistentVolumeClaim using EBS storage class
# Note: With WaitForFirstConsumer binding mode, PVC stays Pending until pod is scheduled
resource "kubernetes_persistent_volume_claim_v1" "web_app_storage" {
  metadata {
    name      = "web-app-storage"
    namespace = "default"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp3" # Uses the default EBS storage class created by the module

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }

  # Don't wait for binding - with WaitForFirstConsumer it won't bind until pod is scheduled
  wait_until_bound = false

  depends_on = [
    module.eks
  ]
}

# Deployment with web application and EBS volume
resource "kubernetes_deployment_v1" "web_app" {
  metadata {
    name      = "web-app"
    namespace = "default"
    labels = {
      app = "web-app"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "web-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "web-app"
        }
      }

      spec {
        # Init container to populate the volume with content
        init_container {
          name    = "init-content"
          image   = "busybox:latest"
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
              cat > /usr/share/nginx/html/index.html <<EOF
              <!DOCTYPE html>
              <html>
              <head>
                <title>EBS Persistent Volume Demo</title>
                <style>
                  body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
                  .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                  h1 { color: #333; }
                  p { color: #666; line-height: 1.6; }
                  .info { background: #e3f2fd; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
                </style>
              </head>
              <body>
                <div class="container">
                  <h1>EBS Persistent Volume Demo</h1>
                  <div class="info">
                    <p><strong>Success!</strong> This content is stored on an EBS volume.</p>
                    <p>The volume is mounted at: <code>/usr/share/nginx/html</code></p>
                    <p>This data will persist even if the pod is deleted and recreated.</p>
                  </div>
                  <p>To verify persistence, create a file in this directory and restart the pod - the file will still be there!</p>
                </div>
              </body>
              </html>
              EOF
            EOT
          ]

          volume_mount {
            name       = "web-storage"
            mount_path = "/usr/share/nginx/html"
          }
        }

        container {
          name  = "web-server"
          image = "nginx:alpine"

          port {
            container_port = 80
            name           = "http"
          }

          volume_mount {
            name       = "web-storage"
            mount_path = "/usr/share/nginx/html"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }
        }

        volume {
          name = "web-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.web_app_storage.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim_v1.web_app_storage
  ]
}

# Service to expose the web application
resource "kubernetes_service_v1" "web_app" {
  metadata {
    name      = "web-app"
    namespace = "default"
    labels = {
      app = "web-app"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "web-app"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
      name        = "http"
    }
  }

  depends_on = [
    kubernetes_deployment_v1.web_app
  ]
}
