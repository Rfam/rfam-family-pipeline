#!/usr/bin/env python

import os
import sys
import string
import random
import subprocess

import lib.k8s_manifests as k8s_lib
from subprocess import Popen, PIPE

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
	a password and a home directory 
	
	username: A valid non existing username
	expire_date: The date the user account will expire (YYYY-MM-DD)
	group: The group the user belongs to (beginner, intermediate, expert, guru)

	return: void
	"""
	
	cmd = "useradd --create-home --expiredate %s --shell /usr/bin/bash --password %s %s" 

	# TODO - return passwork or update the database
	# need to email users with username and password
	password = generate_random_password()

	# Create a user with password and shell information
	# potentially load this information from the database
	subprocess.call(cmd % (expire_date, password, username), shell=True)
	
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

def create_new_user_login_deployment():
	pass

# ------------------------------------------------------------------

if __name__=='__main__':

	create_user_pvc("koullis", size=2)
