#!/usr/bin/env python


import os
import sys
import argparse

#from kubernetes import client, config, utils


# --------------------------------------------------------------------------------------------


def create_new_user_login_pod(username):
	"""
	
	"""

	config.load_incluster_config()
    	k8s_client = client.ApiClient()

	k8s_deployment_str = """
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

	k8s_deployment_str = k8s_deployment_str.replace("USERID", username)

	login_deployment = os.path.join("/tmp", "rfam_k8s_login.yaml")
	
	fp = open(login_deployment, 'w')
	fp.write(login_deployment % username)
	fp.close()

	k8s_api = utils.create_from_yaml(k8s_client, login_deployment)

# --------------------------------------------------------------------------------------------

if __name__=="__main__":
	
	pass
