#!/usr/bin/env python

import os
import sys
import argparse
import subprocess

from subprocess import Popen, PIPE
#from kubernetes import client, config, utils


# --------------------------------------------------------------------------------------------


def create_new_user_login_pod(username):
	"""
	This function creates a new user login pod using a kubernetes deployment manifest.
	The purpose of the login pods is to provision the users with interactive sessions
	and access to the rfam curation pipeline on the Cloud.

	username: A valid Rfam cloud account username

	return: void	
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

def check_k8s_login_deployment_exists(username):

	"""
	Uses kubectl to check if a login pod for a specific user exists.
	Returns True if the login pod exists, False otherwise

	username: A valid Rfam cloud account username

	return: Boolean
	"""
	
	k8s_cmd_args = ["kubectl", "get", "pods", "--selector=user=%s,tier=frontend" % username]	
	process = Popen(k8s_cmd_args, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        output, err = process.communicate()

        login_pod = output.strip().split('\n')[1:]

	if len(login_pod) == 0:
		return False
	
	return True

# --------------------------------------------------------------------------------------------

if __name__=="__main__":

	pass
