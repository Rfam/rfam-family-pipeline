#!/usr/bin/env python

import os
import sys
import string
import random
import subprocess
import argparse
import smtplib

import rfcloud
import lib.k8s_manifests as k8s_lib

from email.message import EmailMessage
from subprocess import Popen, PIPE

# ----------------------------------------------------------------------------------------------------------------

# user account sizes based on expertise level
ACCOUNT_SIZE = {"beginner": 1,
		"intermediate": 1,
		"expert": 2,
		"guru": 5}

# ----------------------------------------------------------------------------------------------------------------

def generate_random_password(length=10):
	"""
	Generates a random password with the length specified as a parameter.
	length: The length of the password to be generated. Default length is 10

	returns: A random password as a string 
	"""

	chars = string.ascii_uppercase + string.ascii_lowercase + string.digits + "&$!"

	random_password = ''.join(random.choice(chars) for x in range(length))

	return random_password

# ----------------------------------------------------------------------------------------------------------------

def create_new_rfam_user(username, expire_date, group):
	"""
	Uses useradd tool to create a new user account with expire date
	a password and a home directory. Returns True if the account was 
	created successfully, False otherwise.
	
	username: A valid non existing username
	expire_date: The date the user account will expire (YYYY-MM-DD)
	group: The group the user belongs to (beginner, intermediate, expert, guru)

	return: Boolean
	"""

	# TODO - generate a uid too
	
	cmd = "useradd --create-home --expiredate %s --shell /usr/bin/bash --password %s %s" 

	user_home_dir = os.path.join("/home", username):
	
	# check account does not already exist
	if os.path.exists(user_home_dir)
		print ("ERROR: Unable to create an account for %s. Account already exists!" % username)
		return False

	# TODO - return passwork or update the database
	# need to email users with username and password
	password = generate_random_password()

	# Create a user with password and shell information
	# potentially load this information from the database
	subprocess.call(cmd % (expire_date, password, username), shell=True)

	return True	

# ----------------------------------------------------------------------------------------------------------------

def setup_kube_dir(username):
	# creates .kube dir and sets the config file
	home_dir_path = os.path.join("/home", username)

	# create .kube dir
	kube_dir = os.path.join(home_dir_path, ".kube")
	os.mkdir(kube_dir)
	os.chmod(444) # make read only for all
	
	# TODO
	# create .kube/config
	
# ----------------------------------------------------------------------------------------------------------------


def create_user_pvc(username, size=2):
	"""
	This function creates a new k8s user persistent volume claim (PVC)
	and prints out relevant messages upon success or failure. The user's
	username and pvc size is specified as a parameter. If the pvc is
	created successfully then the function returns true, False otherwise.

	username: A valid Rfam cloud user username
	size: The size of the volume in Gi

	return: True on success, False on failure 
	"""

	cmd_args = ["kubectl", "get", "pvc", "--selector=user=%s"%username]
	user_pvc_manifest = k8s_lib.user_pvc_manifest
	
	# get pvc manifest temp location
	pvc_manifest_loc = os.path.join("/tmp", username+"_pvc.yml")

	# check if the pvc exists and is Bound
	if check_pvc_exists(username) is True:
		print ("PVC of user %s already exists!" % username)
		
		return True

	# open a temp file and write the k8s pvc manifest
	fp = open(pvc_manifest_loc, 'w')
	fp.write(user_pvc_manifest% (username, username, size))
	fp.close()

	# check if the pvc manifest was created 
	if os.path.exists(pvc_manifest_loc):
		cmd_args = ["kubectl", "create", "-f", pvc_manifest_loc]
		process = Popen(cmd_args, stdin=PIPE, stdout=PIPE, stderr=PIPE)
		response, err = process.communicate()
		
		# check if pvc was created
		if str(response).find("created") != -1:
			# need an infinite loop here to check when the pvc will change status from
			# Pending to Bound
			print ("PVC for user %s has been created" % username)		
			
			# check if newly created PVC is bound
			response = False			
			# keep checking while the pvc is not Bound
			while(not response):
				response = check_pvc_exists(username)

			print ("PVC of user %s is Bound!" % username)
		else:
			sys.exit("ERROR creating pvc manifests for user %s" % username)
			return False
	
	else:
		sys.exit("ERROR creating pvc manifest file for user %s" % username)
		return False

	# remove pvc manifest when done
	os.remove(pvc_manifest_loc)
	return True

# ----------------------------------------------------------------------------------------------------------------

def check_pvc_exists(username):
	"""
	This function checks if a user persistent volume claim (PVC) already exists.
	Returns True if the PVC exists, False otherwise.

	username: The username of an Rfam cloud user
	
	return: Boolean
	"""
	
	cmd_args = ["kubectl", "get", "pvc", "--selector=user=%s"%username]
	
	process = Popen(cmd_args, stdin=PIPE, stdout=PIPE, stderr=PIPE)
	response, err = process.communicate()

	if str(response).find("Bound") != -1:
		return True

	return False

# -----------------------------------------------------------------

def create_new_user_login_deployment(username, multi=False):
	"""
	Creates a new login deployment for a specified user if one does
	not already exist. 

	username: The username of an existing Rfam cloud user
	multi: 
	"""

	# check if login pod already exists
	login_pod_exists = check_k8s_login_deployment_exists(username)

	if login_pod_exists is True:
		if multi is True:
			print("User %s login pod already exists" % username)
			return get_k8s_login_pod_id(username)
		# if single user print message and exit
		else:
			sys.exit("User %s login pod already exists" % username)
	# there's no login pod for user specified by username	
	else:
		# create a new login pod for user 
		rfcloud.create_new_user_login_pod(username)
		
		check_pod_exists = check_k8s_login_deployment_exists(username)

		# keep checking until the pod gets created
		while (not check_pod_exists):
			check_pod_exists = check_k8s_login_deployment_exists(username)

		print ("Login pod for user %s has been created!\n" % username)

# ----------------------------------------------------------------------------------------------------------------

def email_new_rfam_user_account_credentials(username, password, email):
	"""
	Emails a new Rfam cloud user their account credentials to
	access the system.

	username: An existing Rfam cloud username
	password: The newly created account password
	email: A valid user's email address

	return void
	"""

	
 
# ------------------------------------------------------------------

def is_file(param):
        """
        Function to support argparse functionality. Checks if parameter provided is
        actually a file.

        param: Argparse parameter

        return: The parameter
        """

        if not os.path.isfile(param):
                raise argparse.ArgumentTypeError('Parameter much be a .txt file')

        return param

# ------------------------------------------------------------------

def parse_arguments():
	"""
	Uses python's argparse to parse the command line arguments
	
	return: Argparse parser object
	"""

	# create a new argument parser object
	parser = argparse.ArgumentParser(description='Tool to create new Rfam cloud users')

	parser.add_argument('-f', help='a file containing all necessary information to create Rfam cloud user accounts', 
		action="store", type = is_file(), metavar="FILE")
	
	return parser

# ------------------------------------------------------------------

def activate_login_pod_in_user_home(username):
	"""
	Modifies .bashrc and .profile files in the user's home directory
	to directly access the interactive login pod when connecting the
	Rfam cloud edge node. 

	username: An existing Rfam cloud username
	"""

	user_login_pod_id = ""

	# check login pod exists and get its id
	if check_k8s_login_deployment_exists(username):
		user_login_pod_id = get_k8s_login_pod_id(username)
	else:
		sys.exit("ERROR: Login pod of user %s does not exist" % username)

	# get the user home directory and check it exists
	user_home_dir = os.path.join("/home", username)

	# some sanity checks
	if not os.path.exists(user_home_dir):
		sys.exit("ERROR: Home directory of user %s does not exist" % username)

	bashrc_path = os.path.join(user_home_dir, ".bashrc")
	profile_path = os.path.join(user_home_dir, ".profile")
	
	kubectl_exec_cmd = "kubectl exec -it %s bash" % username

	# call kubectl exec in user bashrc
	try:
		subprocess.call("echo %s >> %s" % (kubectl_exec_cmd, bashrc_path), shell=True)
	except:
		sys.exit("ERROR: User %s bashrc file could not be updated" % username)


	# call kubectl exec in user profile
	try:
		subprocess.call("echo %s >> %s" % (kubectl_exec_cmd, profile_path), shell=True)
	except:
		sys.exit("ERROR: User %s profile file could not be updated" % username)


# ------------------------------------------------------------------
if __name__=='__main__':

	parser = parse_arguments()
	args = parser.parse_args()

	if args.f:
		user_list_fp = open(args.f, 'r')
	
		for user_line in user_list_fp:
			# TODO username\tuid\tcuration_level\texpire_date\group
			# username, curation_level,expire_date for now
			user_info = user_line.strip().split('\t')

		user_list_fp.close()			
