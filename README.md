# Sync-Studio-Pack

When ejecuted, it lookup first in CLOUD_PROJECTS_DIRECTORY for existing projects packed in tar.bz2
and uses rsync to sync the files localy but only if the local copy is out dated, later execute
Android Studio.
 
When Android Studio is closed, it lookup in LOCAL_PROJECTS_DIRECTORY for files changed after
Android Studio startup, pack only modified projects and copy them to CLOUD_PROJECTS_DIRECTORY.

Very useful if you work from several places and want to have in all places the same code.
Executing Android Studio in this manner, before it starts, all the projects will be updated.
And all the projects modified, later will be copied back to Dropbox, ownCloud, MegaSync, etc.

A vulgar solution if you don't use any Version Control System
