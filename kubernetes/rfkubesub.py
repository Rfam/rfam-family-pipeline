#!/usr/bin/env python3

import sys
import os
import getpass
import socket

from kubernetes import client, config, utils

# -----------------------------------------------------------------------------------

def main():

    # Configs can be set in Configuration class directly or using helper
    # utility. If no argument provided, the config will be loaded from
    # default location.
    
    config.load_incluster_config()
    k8s_client = client.ApiClient()
    
    cmd = sys.argv[1]
    cpus = int(sys.argv[2])
    memory = sys.argv[3]
    job_index = sys.argv[4]

    #convert to milicores
    cpus = cpus * 1000
    hostname = socket.gethostname()
    user = hostname.split('-')[3] # fetch username from pod hostname
    job_name = "rfsearch-job-%s-%s" % (user, job_index)
    pod_name = "rfsearch-pod-%s-%s" % (user, job_index) # check if a uuid is needed
    volume_name = "rfam-pod-storage-%s" % user
    pvc_name = "rfam-pvc-%s" % user
    
    # rfsearch job manifest
    rfam_k8s_job = ("apiVersion: batch/v1\n"
    	"kind: Job\n"
    	"metadata:\n"
    	"  name: %s\n"
    	"spec:\n"
        #"  activeDeadlineSeconds: 30\n"
        "  ttlSecondsAfterFinished: 10\n"
    	"  template:\n"
    	"    metadata:\n"
    	"      name: %s\n" 
    	"      labels:\n"
    	"        app: family-builder\n"
    	"        user: %s\n"
    	"        tier: backend\n"
        "        jobname: %s\n"
    	"    spec:\n"
        "      volumes:\n"
        "        - name: nfs-volue\n"
        "          nfs:\n"
        "            server: 193.62.55.16\n"
        "            path: /nfs2\n"
        "            port: \"2049\"\n"
    	"      containers:\n"
    	"      - name: %s\n"
    	"        image: rfam/cloud:kubes\n"
    	"        resources:\n"
    	"          limits:\n"
    	"            cpu: \"8000m\"\n" # maximum number of cpus to be used in the docker container
        "            memory: \"24Gi\"\n" # maximum memory to be used in the docker container
    	"          requests:\n"
    	"            cpu: \"%sm\"\n"
        "            memory: \"%sMi\"\n"
        #"        args:\n"
        #"        - -cpus\n"
        #"        - \"%s\"\n"
    	"        command: [\"sh\", \"-c\", \"%s\"]\n"
    	"        imagePullPolicy: Always\n"
    	"        volumeMounts:\n"
                "        - name: nfs-pv\n"
                "          mountPath: /Rfam/rfamseq\n"
		"        - name: %s\n" # this one must match the volume name of the pvc
		"          mountPath: /workdir\n"
		"      volumes:\n"
		"      - name: %s\n"
		"        persistentVolumeClaim:\n"
		"          claimName: %s\n"
                "      - name: nfs-pv\n"
                "        persistentVolumeClaim:\n"
                "          claimName: nfs-pvc\n"
		"      restartPolicy: OnFailure")

    
    # create a new k8s job yaml file
    rfjob_manifest = os.path.join("/tmp", "rfjob.yaml") # does not need to be deleted 
    fp = open(rfjob_manifest, 'w')
    fp.write(rfam_k8s_job % (job_name, pod_name, user, job_name, pod_name, cpus, memory, cmd, volume_name, volume_name, pvc_name))
    fp.close()
    
    #print rfam_k8s_job %(job_name, pod_name, user, job_name, pod_name, cpus, cmd, volume_name, volume_name, pvc_name)
    
    # this will be generated
    k8s_api = utils.create_from_yaml(k8s_client, rfjob_manifest)

    # create unique namespace for each user
    #deps = k8s_api.read_namespaced_deployment(job_name, "default")

    #print("Deployment {0} created".format(deps.metadata.name))
    
    
# -----------------------------------------------------------------------------------

if __name__ == '__main__':

	main()
