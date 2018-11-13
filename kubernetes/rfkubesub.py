import sys
import os
import pwd
import config as rc

from kubernetes import client, config, utils

# -----------------------------------------------------------------------------------

def main():

    # Configs can be set in Configuration class directly or using helper
    # utility. If no argument provided, the config will be loaded from
    # default location.
    config.load_kube_config()
    k8s_client = client.ApiClient()

    user = pwd.getpwnam('aix').pw_uid
    job_name = "rfam_" + user
    cmd = sys.argv[1]
    cpus = sys.argv[2]
    pod_template = "rfam-pod" # check if a uuid is needed
    image = rc.RFAM_CLOUD_IMG
    user_dir = os.getcwd()

    rfam_job = """
				apiVersion: batch/v1
				kind: Job
				metadata:
				  name: %s
				  namespace: %s
				spec:
				  template:
				    metadata:
				      name: %s 
				      labels:
				        user: %s
				    spec:
				      containers:
				      - name: %s
				        image: ikalvari/rfam-cloud:inpod-kubectl
				        resources:
				          limits:
				            cpu: 8
				      imagePullPolicy: IfNotPresent
				        command: %s
				 		args:
				 		- -cpus
				 		- 8 
				      restartPolicy: Never
				    volumes:
				      mountPoint: 
			      """

    rfjob_manifest = os.path.join("/tmp", "rfjob.yaml") # does not need to be deleted 
    fp = open().write(rfam_job % (job_name, pod_template, user, pod_template, image, cmd))
    fp.close()
    
    # this will be generated
    k8s_api = utils.create_from_yaml(k8s_client, rfjob_manifest)

    # create unique namespace for each user
    deps = k8s_api.read_namespaced_deployment(job_name, "default")

    print("Deployment {0} created".format(deps.metadata.name))

# -----------------------------------------------------------------------------------

if __name__ == '__main__':
    
    main()
