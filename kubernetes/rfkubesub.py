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
    job_name = "rfsearch-job-%s" % user
    pod_name = "rfsearch-pod-%s" % user # check if a uuid is needed
    volume_name = "rfsearch-pod-storage-%s" % user
    pvc_name = "rfam-pvc-%s" % user
    
    # rfsearch job manifest
    rfam_k8s_job = ("apiVersion: batch/v1\n"
	"kind: Job\n"
	"metadata:\n"
	"  name: %s\n"
	"spec:\n"
	"  template:\n"
	"    metadata:\n"
	"      name: %s\n" 
	"      labels:\n"
	"        app: family-builder\n"
	"        user: %s\n"
	"        tier: backend\n"
	"    spec:\n"
	"      containers:\n"
	"      - name: %s\n"
	"        image: ikalvari/rfam-cloud:inpod-kubectl\n"
	"        resources:\n"
	"          limits:\n"
	"            cpu: 8\n"
	"          requests:\n"
	"            cpu: 8\n"
	"        command: [%s]\n"
	"        imagePullPolicy: IfNotPresent\n"
	"        restartPolicy: OnFailure\n"
	"        volumeMounts:\n"
	"        - name: %s\n" # this one must match the volume name of the pvc
    "          mountPath: /workdir\n"
	"      volumes:\n"
	"      - name: %s\n"
    "        persistentVolumeClaim:\n"
    "          claimName: %s\n")

    
    # create a new k8s job yaml file
    rfjob_manifest = os.path.join("/tmp", "rfjob.yaml") # does not need to be deleted 
    fp = open(rfjob_manifest, 'w')
    fp.write(rfam_k8s_job % (job_name, pod_name, user, pod_name, cmd, volume_name, volume_name, pvc_name))
    fp.close()
    
    # this will be generated
    k8s_api = utils.create_from_yaml(k8s_client, rfjob_manifest)

    # create unique namespace for each user
    deps = k8s_api.read_namespaced_deployment(job_name, "default")

    print("Deployment {0} created".format(deps.metadata.name))
    
# -----------------------------------------------------------------------------------

if __name__ == '__main__':
    
    main()