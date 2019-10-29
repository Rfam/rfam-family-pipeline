#!/usr/bin/env python

import os
import sys
import string
import random
import subprocess
from subprocess import Popen, PIPE

# ------------------------------------------------------------------

def generate_random_password(length=10):
	"""
	Generates a random password with the length specified as a parameter.
	length: The length of the password to be generated. Default length is 10

	returns: A random password as a string 
	"""

	chars = string.ascii_uppercase + string.ascii_lowercase + string.digits + "&$!"

	random_password = ''.join(random.choice(chars) for x in range(length))

	return random_password

# ------------------------------------------------------------------

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
	
# ------------------------------------------------------------------

def setup_kube_dir(username):
	# creates .kube dir and sets the config file
	home_dir_path = os.path.join("/home", username)

	# create .kube dir
	kube_dir = os.path.join(home_dir_path, ".kube")
	os.mkdir(kube_dir)
	os.chmod(444) # make read only for all
	
	# TODO
	# create .kube/config
	
# ------------------------------------------------------------------


def create_user_pvc(username, size=2):
	pass

# ------------------------------------------------------------------

def create_new_user_login_deployment():
	pass

# ------------------------------------------------------------------


if __name__=='__main__':

	pass
