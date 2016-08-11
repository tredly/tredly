# Configuring Tredly
Once you have Tredly installed, the next thing you will want to do is configure it. For this guide I am going to use a production example (from one of the large Tredly users) of configuring Tredly.

First thing you will want to do is create Partitions on Tredly so you can organize your containers into logical groups of containers.

## SSH into Tredly and run:
```
tredly create partition Prod
tredly create partition Stage
```
When you create these partitions, Tredly will create a ZFS dataset and folders within that dataset for that partition. Using the "Prod" partition example, the path on the host will be /tredly/ptn/Prod/. Within this path, there will be the following folders created:

### cntr
When you create a container, Tredly creates a folder (by UUID for each container
data
When you use /partition within your Tredlyfile, this is the location you are referencing. You can create any combination or number of file folders within this folder.
### data
Where you store any data that is specific to this partition. Some examples include credentials, ssl certificates, and common files for your containers.
### psnt
Persistent Storage folder for the containers within the partition
### containers
The raw container files/folders that have been pushed to the partition.
Because the API does not provide all the features required to solve the needs for everyone, rsync is used to move the data to the container.
- Credentials, scripts and sslCerts are transferred over to Tredly
- Containers are transferred over to Tredly

To create the "Prod" partition a script is run to create all containers in the order you want them created. This script was transferred above.

Before creating the containers DNS (or the loadbalancer) has been updated so that all URLs serviced by containers in the Prod partition, point to the new Tredly Host.

The Prod creation script is run and about 10 minutes later (for approx 30 containers) all containers are up and running.
