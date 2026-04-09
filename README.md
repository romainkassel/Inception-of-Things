## P3

### Difference between k3s and k3d

- k3s allows to create a cluster directly on a VM
- k3d allows to create a cluster inside a Docker container, no VM required

### App deployment

To test that the app has been well deployed inside its pod:
1. Inside the VM, execute : `sudo kubectl port-forward --address 0.0.0.0 svc/service-www 8888:80 -n dev`
2. Inside the VM again, from another terminal, execute `curl http://localhost:8888`

It should return `Hello World v{tagVersion}!`

### Custom Docker app image

1. Build image with specific architecture: `docker build --platform linux/arm64 -t rkassel/playground:v{tagVersion} .`
2. Push the image on Docker Hub: `docker push rkassel/playground:v{tagVersion}`

Before pushig the image, you can also test it locally and outside the VM by:
1. Retrieving the image ID after build: `docker image ls`
2. Running it with a port mapping between Docker and the host machine: `docker run -p 8888:8888 {imageId}`
3. Curling the port inside another terminal: `curl http://localhost:8888`

It should return `Hello World v{tagVersion}!`

### Argo CD

To access Argo CD Dashboard from host machine:
1. Setup a forwarding port inside Vagrant file: `config.vm.network "forwarded_port", guest: 8443, host: 8443`
2. Inside the VM, launch: `sudo kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8443:443`
3. Then just access to `http://localhost:8443` from the browser of your host machine

Dashboard credentials:
- Username: always `admin`
- Password: get it by running `sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo` inside the VM

## Bonus

### Increase VM size disk for Mac

These steps need to be done before `vagrant up`.

#### List available boxes

`vagrant box list`

#### Remove the box you want to use

`vagrant box remove {boxName} --provider libvirt --force`

For instance, `vagrant box remove cloud-image/debian-13 --provider libvirt --force`

#### Verify the box has been removed

`vagrant box list`

#### Add the box of your choice manually

`vagrant box add {boxName} --provider libvirt`

For instance, `vagrant box add cloud-image/debian-13 --provider libvirt`

#### Verify the box has been added

`vagrant box list`

#### Find the new box file path

`find ~/.vagrant.d/boxes -name "box.img"`

#### Increase the box size

`qemu-img resize {boxLocation} +30G`

#### Start the VM

`vagrant up`

#### Connect to the VM

`vagrant ssh`

Now, the following steps can done directly inside the Vagrant provisionning script

#### Check size of the parent disk (all new space available)

`lsblk`

#### Check real disk size available

`df -h /`

#### Resize disk size

These steps can be not necessary for modern images as `cloud-image` as they automatically resize depending on the available space.

`sudo growpart /dev/vda 1`
`sudo resize2fs /dev/vda1`

#### Check disk size AFTER

`df -h /`

### Gitlab

Latest relases: `https://about.gitlab.com/releases/categories/releases/`
Check current version installed: `sudo helm list -n gitlab`

By default, the latest version available inside the Gitlab repo is installed by Helm.

#### See space used by services

`sudo kubectl get pvc -A`

#### Apply Gitlab YAML file updates

```
exit
vagrant rsync
vagrant ssh
sudo kubectl delete jobs --all -n gitlab
sudo helm upgrade gitlab gitlab/gitlab -f ./confs/01-gitlab.yaml -n gitlab --force
sudo kubectl get pods -n gitlab
```

#### See logs related to a pod

`sudo kubectl describe pod -n gitlab [POD_NAME]`

#### URLs

- Dashboard (projects of which I am a member): `http://gitlab.localhost:8888/dashboard/projects`
- Admin area (all instance projects): `http://gitlab.localhost:8888/admin/projects`
- Project repository: `http://gitlab.localhost:8888/root/iot-app-rkassel`

#### How to test?

When the provisionning script is finished and the VM is ready, you can do the following steps.

##### Access to ArgoCD UI

1. Connect to VM: `vagrant ssh`
2. Retrieve ArgoCD password: `sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`
3. Create a tunnel to access ArgoCD UI from your host machine or VM: `sudo kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8443:443`
4. From your host machine/VM browser, access ArgoCD UI through the following URL: `http://localhost:8443`
5. Login (`username` is `admin` and `password` is the password you retrieved in step 3)
6. Once connected to ArgoCD, click on the `app-simple` card project
7. If everything is green, it means that the app has been deployed and is available

##### Access to Gitlab UI

1. Open a new terminal
2. Go to bonus folder: `cd bonus`
3. Connect to VM: `vagrant ssh`
4. Retrieve Gitlab admin password: `sudo kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode; echo`
5. From your host machine/VM browser, access Gitlab admin UI through the following URL: `http://gitlab.localhost:8888`
6. Login (`username` is `root` and `password` is the password you retrieved in step 4)
7. Click on `Project` in the left sidebar
8. In the `Projects` section, click on the `Administrator / iot-app-rkassel` project
9. In the repository, click on the `confs` folder
10. Click on the `00-deployment.yaml ` file

The attibute `spec.template.spec.containers.image` should be equal to `rkassel/playground:v1`.

It means that the current deployed app is the V1 version.

##### Check deployed app response

###### From Host machine/VM - Browser

From your host machine/VM browser, enter the following URL: `http://app.localhost:8888`.

It should return:

```
status: "ok"
version: "v1"
```

###### From Host machine/VM - Terminal

From your host machine/VM terminal, run the following command: `curl http://app.localhost:8888`.

It should return `{"status":"ok","message":"v1"}`

###### From VM

1. Open a new terminal
2. Go to bonus folder: `cd bonus`
3. Connect to VM: `vagrant ssh`
4. Run `curl http://app.localhost:8888`

It should return `{"status":"ok","message":"v1"}`

##### Update app version

###### Update image tag version

1. Go back to the Gitlab admin UI 
2. Edit the repository by clicking on `Edit`
3. Select `Edit in a single file`
4. Replace `image: rkassel/playground:v1` by `image: rkassel/playground:v2`
5. Click on `Commit changes` twice
6. Check that the image tag version has been updated from v1 to v2

###### Check deployment on ArgoCD

1. Go back to ArgoCD UI
2. Check the `POD` card (on the right)
3. Just wait, the UI will refresh automatically

> [!NOTE]
> It can take a few minutes for ArgoCD to detect the update inside the Gitlab repository, sometimes up to 5/10 minutes.
> 
> In the meantime, you can hover the `POD` card and you will see that the current deployed image is `rkassel/playground:v1`.

As soon as ArgoCD detects the image version update, it will display 2 PODS:
- the new one
- and the old one (that is being destroyed)

If the healthy POD contains the `rkassel/playground:v2` image, it means that the new app version has been deployed and is available.

###### Check new version

You can check the new version by repeating the steps from the section `Check deployed app response`.
Now, the app should return `"message":"v2"` instead of `"message":"v1"`

## Vagrant on Mac

### How to setup a VM on Mac with Vagrant?

1. Update Brew: `brew update`
2. Install Vagrant: `brew install vagrant`
3. Install Qemu plugin for Vagrant: `vagrant plugin install vagrant-qemu`
4. Access to the VM in SSH mode: `vagrant ssh`

### Find a box name

To find the box name to use in the Vagrantfile:
1. Go on [https://portal.cloud.hashicorp.com/vagrant/discover?query=](https://portal.cloud.hashicorp.com/vagrant/discover?query=)
2. Set `Provider` to `qemu`
3. Set `Architecture` to the one related to your Mac (`uname -m`)
4. In the search bar, search for the LTS of the OS you want to install (by typing `debian trixie` for instance)

## Other sources

- Kubernetes Namespaces: [https://kubernetes.io/docs/tasks/administer-cluster/namespaces/](https://kubernetes.io/docs/tasks/administer-cluster/namespaces/)