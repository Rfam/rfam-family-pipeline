
# Manifest to create user PVC

user_pvc_manifest="""
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
 name: rfam-pvc-%s
 labels:
   user: %s
 annotations:
  volume.beta.kubernetes.io/storage-class: gluster-heketi
spec:
  accessModes:
   - ReadWriteMany
  resources:
    requests:
      storage: %sGi"""

# Manifest to create user login deployment

user_login_deployment_str = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rfam-login-pod-USERID
  labels:
    app: rfam-family-builder-USERID
    tier: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rfam-family-builder-USERID
  template:
    metadata:
      name: rfam-login-pod-USERID
      labels:
        app: rfam-family-builder-USERID
        user: USERID
        tier: frontend  
    spec:
      containers:
      - name: rfam-login-pod-USERID
        image: ikalvari/rfam-cloud:kubes
        imagePullPolicy: Always
        ports:
        - containerPort: 9876
        volumeMounts:
        - name: rfam-login-pod-storage-USERID # this one must match the volume name of the pvc
          mountPath: /workdir
        - name: nfs-pv
          mountPath: /Rfam/rfamseq
        stdin: true
        tty: true
      volumes:
      - name: rfam-login-pod-storage-USERID
        persistentVolumeClaim:
          claimName: rfam-pvc-USERID # this one must match the pvc name
      - name: nfs-pv
        persistentVolumeClaim:
          claimName: nfs-pvc
      restartPolicy: Always"""
