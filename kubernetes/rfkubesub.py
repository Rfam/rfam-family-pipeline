import sys
import os
import getpass

from kubernetes import client, config, utils

# -----------------------------------------------------------------------------------

def main():

    # Configs can be set in Configuration class directly or using helper
    # utility. If no argument provided, the config will be loaded from
    # default location.
    config.load_kube_config()
    k8s_client = client.ApiClient()

    cmd = sys.argv[1]

    user = getpass.getuser()
    job_name = "rfam-job-" + user
    pod_template = "rfam-pod-" + user # check if a uuid is needed
    volume_name = "rfam-pod-storage-" + user
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
				      volumeMounts:
    				  - name: rfam-pod-storage # this one must match the volume name of the pvc
      					mountPath: /workdir
				    volumes:
				    - name: rfam-pod-storage
    				  persistentVolumeClaim:
      				    claimName: rfam-pod-pvc
			      """

    rfjob_manifest = os.path.join("/tmp", "rfjob.yaml") # does not need to be deleted 
    fp = open(rfjob_manifest, 'w')
    fp.write(rfam_job % (job_name, user, pod_template, user, pod_template, cmd))
    fp.close()
    
    # this will be generated
    k8s_api = utils.create_from_yaml(k8s_client, rfjob_manifest)

    # create unique namespace for each user
    deps = k8s_api.read_namespaced_deployment(job_name, "default")

    print("Deployment {0} created".format(deps.metadata.name))

# -----------------------------------------------------------------------------------

if __name__ == '__main__':
    
    main()
