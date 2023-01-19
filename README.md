# ExternalDns

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    iam.gke.io/gcp-service-account: ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
  name: ${KSA_NAME}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${KSA_NAME}
rules:
  - apiGroups: ["extensions","networking.gke.io"]
    resources: ["multiclusteringresses"]
    verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${KSA_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ${KSA_NAME}
subjects:
  - kind: ServiceAccount
    name: ${KSA_NAME}
    namespace: default # change if namespace is not 'default'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: default
  labels:
    app: external-dns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: ${KSA_NAME}
      containers:
        - name: external-dns
          image: ghcr.io/corp-momenti/external-dns:v0.1.0
          resources:
          ...
```

```yaml
apiVersion: networking.gke.io/v1
kind: MultiClusterIngress
metadata:
  name: foo
  annotations:
    external-dns/managed-zone: ${CLOUD_DNS_MANAGED_ZONE}
    external-dns/hostname: ${HOST_NAME} # ex) foo.example.com 
    ...
spec:
  template:
    spec:
      backend:
        serviceName: foo
        ...
```
