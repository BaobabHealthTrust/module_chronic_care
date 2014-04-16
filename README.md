chronic-care-module
===================

Management of chronic non-communicable diseases

Installation
1
On the applications server
	Clone module chronic care from github on >> git@github.com:BaobabHealthTrust/module_chronic_care.git
	Clone user management from github on >> git@github.com:BaobabHealthTrust/core_user_management.git
 	Clone patient registration from github >> git@github.com:BaobabHealthTrust/core_patient_registration.git
2.
	Configuration
		Create database and application .yml files from .example file in all the three applications
		Point all the three applications to the same database
		
	Application.yml
		In CCC, specify the user.management ip address and port as shown in the .example file
		In patient registration, specify where DDE proxy is running and also where user management is running.
		In user management, specify the IP address and port where user management is running
		NOTE: If all the three applications are running on the same port, do not use 127.0.0.1 or localhost

3. 
	vitals Kiosk
	On the client machine where CCC will be accessed, pull app_vitals from github on
			https://github.com/BaobabHealthTrust/app_vitals.git
	install c compiler using
		sudo apt-get install build-essential
        compile the program
		gcc vitalsserver.c -o vitalsserver
	connect the scale on any usb port and the BP machine on the first serial port such that the machile takes ttyUSB0 and scale ttyS0

	run the compiled vitals server on the client by:
		 sudo ./vitalsserver -b /dev/ttyS0 -s /dev/ttyUSB0
	make sure nothing is running on port 3000 on the client machine

4.
	open firefox on the client
		firefox ccc_ip_address:port

5.
	Post installation configuration
	
	Load the file proc_insert_program_encounter.sql into your database to manage data from vitals kiosk

	From properties on clinic dashboard
		1. set up current health center
		2. set up prescription format
		3. set up auto appointments
		



