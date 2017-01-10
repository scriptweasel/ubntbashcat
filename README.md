# ubntbashcat
A bash script that walks a defined subnet and returns details about Ubiquiti wireless hardware.

Requires:
nmap, sshpass

Essentially, this script is to aimed at a fixed wireless network with a mix of Ubiquiti and Mikrotik wireless clients.

It scans through a defined subnet and trys to detect on each IP:

- If port 8291 is open or filtered, if so skips, because this script is currently aimed at Ubiquiti clients.

- If port 22 is open or filtered, if so attempts to establish an ssh connection with one of the pre-defined usernames and passwords at the top of the script

- If ssh is successful, tries to pull specific data by means of several other ssh session commands from the device and store the results in a file in CSV format.


To Do:

Many thoughts on what more I'd like this script to do, such as defining what paramenters to pull, and extending it to also pull data from mikrotik clients, to name a couple.
