#!/usr/bin/env python

import sys
import os
import getpass

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
    job_index = sys.argv[3]

    #convert to milicores
    cpus = cpus * 1000
    user = getpass.getuser()
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
    	"  template:\n"
    	"    metadata:\n"
    	"      name: %s\n" 
    	"      labels:\n"
    	"        app: family-builder\n"
    	"        user: %s\n"
    	"        tier: backend\n"
        "        jobname: %s\n"
    	"    spec:\n"
    	"      containers:\n"
    	"      - name: %s\n"
    	"        image: ikalvari/rfam-cloud:kubes\n"
    	"        resources:\n"
    	"          limits:\n"
    	"            cpu: \"8000m\"\n" # this is the upper limit of the cpus to be used in the docker container
    	"          requests:\n"
    	"            cpu: \"%sm\"\n"
        #"        args:\n"
        #"        - -cpus\n"
        #"        - \"%s\"\n"
    	"        command: [\"sh\", \"-c\", \"%s\"]\n"
    	"        imagePullPolicy: IfNotPresent\n"
    	"        volumeMounts:\n"
		"        - name: %s\n" # this one must match the volume name of the pvc
		"          mountPath: /workdir/CLOUD_TEST\n"
		"      volumes:\n"
		"      - name: %s\n"
		"        persistentVolumeClaim:\n"
		"          claimName: %s\n"
		"      restartPolicy: OnFailure")

    
    # create a new k8s job yaml file
    rfjob_manifest = os.path.join("/tmp", "rfjob.yaml") # does not need to be deleted 
    fp = open(rfjob_manifest, 'w')
    fp.write(rfam_k8s_job % (job_name, pod_name, user, job_name, pod_name, cpus, cmd, volume_name, volume_name, pvc_name))
    fp.close()
    
    print rfam_k8s_job %(job_name, pod_name, user, job_name, pod_name, cpus, cmd, volume_name, volume_name, pvc_name)
    
    # this will be generated
    #k8s_api = utils.create_from_yaml(k8s_client, rfjob_manifest)

    # create unique namespace for each user
    #deps = k8s_api.read_namespaced_deployment(job_name, "default")

    #print("Deployment {0} created".format(deps.metadata.name))
    
    
# -----------------------------------------------------------------------------------

if __name__ == '__main__':

	main()
