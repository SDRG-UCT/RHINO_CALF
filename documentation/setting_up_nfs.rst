Setting up NFS
==============

.. .. toctree::
..    :maxdepth: 2
..    :caption: Contents:

Instructions on how to set up a network file system (NFS) for RHINO.

Using an NFS eases RHINO development, moving files onto the RHINO is as simple as dragging and dropping into a shared directory.

*The following steps assume default values, set up in [prepping the rhino].*

.. todo::
  set up link to "prepping the rhino"

Requirements
------------
RHINO <---usb cable + ethernet cable--->HOST PC

.. todo::
  point to "prepping the rhino/console"
  for now, look at: `the old docs <https://github.com/SDRG-UCT/RHINO_CALF/tree/documentation/quickstart>`_


Host PC
-------

1. 	Install NFS server

.. 	code-block:: sh

	$ sudo apt-get install nfs-kernel-server

2.	Create NFS directory

.. 	code-block:: sh

	$ sudo mkdir /opt/rhinofs
	$ sudo chmod 777 /opt/rhinofs

.. todo::
  need to recursively change permissions of /opt/rhinofs

3.	Point NFS server to RHINO filesystem

.. 	code-block:: sh

	$ sudo chmod 666 /etc/exports
	$ sudo echo "/opt/rhinofs	*(rw,nohide,insecure,no_subtree_check,async,no_root_squash)" >> /etc/exports

4.	Download the `RHINO-filesystem <https://github.com/SDRG-UCT/uct-rhino/raw/master/filesystem/rhinofs.tar.gz>`_

.. todo::
  investigate problems when trying to download + extract using wget/curl

5. 	Extract the filesystem into the NFS directory

.. 	code-block:: sh

	$ sudo tar -xf rhinofs.tar.gz -C /opt/rhinofs

6.  Start NFS server

.. 	code-block:: sh

	$ sudo service nfs-kernel-server start


RHINO
-----

1.	Power on RHINO and interrupt autoboot by pressing any key

2.  (optional) Set NFS as default boot mode

.. 	code-block:: sh

	RHINO # setenv run nfsboot
	RHINO # saveenv

3.	Boot from NFS

.. 	code-block:: sh

	RHINO # run nfsboot

4.	Wait for a new SSH key to be generated
