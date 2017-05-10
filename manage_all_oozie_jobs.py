#!/usr/bin/python

import os, sys, commands

# oozieURL="https://arlhsdatat05.lrd.cat.com:11443/oozie"
oozieURL=str(sys.argv[2])
totalargs = len(sys.argv)
totalargs = totalargs - 1
me = str(sys.argv[0])

if totalargs != 2:
  print "Require exactly 2 arguments please"
  exit (2)
else:
  if str(sys.argv[1]) != "suspend" and str(sys.argv[1]) != "resume" and str(sys.argv[1]) != "kill":
    print "1. Script first arguement must be \"suspend\", \"resume\", or \"kill\" please try again"
    exit (1)
  else:
    print "Attempting to \"" + str(sys.argv[1]) + "\" all oozie jobs running..."

oozieActionAll=str(sys.argv[1])
# os.system("ls " + "-l " + oozieActionAll)
# exit (1)

os.system("export OOZIE_URL=" + oozieURL)

print "Oozie jobs status before ..."
os.system("oozie jobs -oozie " + oozieURL)

print "---------------------------------------------------------"

def killAllRunningJobs(oozieURL):
    runningJobs = commands.getoutput("oozie jobs -oozie " + oozieURL + " -jobtype coordinator | grep -i RUNNING |  awk -F \" \" '{print $1} " )
    print "Current Running Co-ordinator Jobs : " + runningJobs
    for jobs in runningJobs:
        ### os.system("oozie job -oozie " + oozieURL + " -resume " + jobs)
        os.system("oozie job -oozie " + oozieURL + " -" + oozieActionAll + jobs)

print "---------------------------------------------------------"

print "Oozie jobs status after ..."
os.system("oozie jobs -oozie " + oozieURL)
