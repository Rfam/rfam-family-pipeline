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

	password = generate_random_password()
	
	# Create a user with password and shell information
	# potentially load this information from the database
	subprocess.call(cmd % (expire_date, password, username), shell=True)
	
# ------------------------------------------------------------------
	

def setup_home_dir():
	# creates .kube dir and sets the config file
	pass
# ------------------------------------------------------------------


def create_user_pvc(username, size=2):
	pass

# ------------------------------------------------------------------

def create_new_user_login_deployment():
	pass

# ------------------------------------------------------------------


if __name__=='__main__':

	pass
