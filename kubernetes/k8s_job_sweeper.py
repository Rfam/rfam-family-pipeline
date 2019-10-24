#!/usr/bin/env python

import os
import sys
import subprocess
import argparse
from subprocess import Popen, PIPE

# -----------------------------------------------------------------------------------------

def delete_completed_jobs():

	"""
	Uses kubectl command to list all jobs and then checks and deletes
	all completed ones to relieve the k8s scheduler
	"""
	
	# k8s command to delete a job
	deletion_cmd = "kubectl delete job %s"
	
	# k8s command to list all jobs
	cmd_args = ["kubectl", "get", "jobs"]	
	process = Popen(cmd_args, stdin=PIPE, stdout=PIPE, stderr=PIPE)
	output, err = process.communicate()
	
	job_info = output.strip().split('\n')[1:]
	
	# splits job info lines in its elements for easy checking of status
	jobs = [[job_element for job_element in job_line.split(' ') if job_element!=''] for job_line in job_info]
	
	for job in jobs:
		# check if job completed
		if job[1] == '1/1':
			subprocess.call(deletion_cmd % job[0], shell=True)
						
# -----------------------------------------------------------------------------------------

if __name__=='__main__':

	delete_completed_jobs()
