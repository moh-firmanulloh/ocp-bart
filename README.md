# ocp-bart



## Deskripsi

Script ini dibuat untuk melakukan backup-restore-verify terhadap objek yang ada di OCP.

Tujuan utama script ini dibuat untuk memenuhi kebutuhan customer, dengan scope migrasi aplikasi.

## Struktur

```
├── README.md
├── backup-script
│   ├── backup-clusterrolebinding.sh
│   ├── backup-configmap.sh
│   ├── backup-cronjob.sh
│   ├── backup-deployment.sh
│   ├── backup-deploymentconfig.sh
│   ├── backup-destinationrule.sh
│   ├── backup-envoyfilter.sh
│   ├── backup-horizontalpodautoscaler.sh
│   ├── backup-image.sh
│   ├── backup-persistentvolumeclaim.sh
│   ├── backup-project.sh
│   ├── backup-replicaset.sh
│   ├── backup-rolebinding.sh
│   ├── backup-route.sh
│   ├── backup-secret.sh
│   ├── backup-service.sh
│   ├── backup-serviceaccount.sh
│   ├── backup-serviceentry.sh
│   ├── backup-statefulset.sh
│   ├── backup-virtualservice.sh
│   └── docs
├── main.sh
├── migrate.conf
└── restore-script
    ├── docs
    ├── restore-clusterrolebinding.sh
    ├── restore-configmap.sh
    ├── restore-cronjob.sh
    ├── restore-deployment.sh
    ├── restore-deploymentconfig.sh
    ├── restore-destinationrule.sh
    ├── restore-envoyfilter.sh
    ├── restore-horizontalpodautoscaler.sh
    ├── restore-image.sh
    ├── restore-persistentvolumeclaim.sh
    ├── restore-project.sh
    ├── restore-replicaset.sh
    ├── restore-rolebinding.sh
    ├── restore-route.sh
    ├── restore-secret.sh
    ├── restore-service.sh
    ├── restore-serviceaccount.sh
    ├── restore-serviceentry.sh
    ├── restore-statefulset.sh
    └── restore-virtualservice.sh
```

## main.sh

Script main.sh merupakan script utama, jika bertujuan untuk backup/restore/verify secara keseluruhan objek pada sebuah project.

Script main.sh berfungsi sebagai jembatan memanggil script lainnya, yang akan memanggil secara berurutan. Pada script ini, args yang diperlukan oleh script lainnya akan otomatis tersusun, selama variable pada _migrate.conf_ sudah dikonfigurasi.

Sub-script yang dipanggil oleh main.sh, contohnya backup-deployment.sh, dibuat secara terpisah untuk memudahkan kustomisasi/penyesuaian untuk masing-masing object, dan memungkinkan untuk menyesuaikan objek apa saja yang akan dilakukan backup/restore/verify.

Perlu mengubah variabel pada _migrate.conf_ ketika menjalankan script.

|Variable|Expected Value|Remarks|
|--------|--------------|--------------|
|script_mode=|backup/restore/verify|
|projects=|Array Nama project pada OCP|("project-a" "project-b")
|ocp_source=|URL API OCP Source|
|ocp_source_user=$4|OCP Source Username|
|ocp_source_pass=$5|OCP Source Password|
|ocp_registry_source=$9|OCP Source Registry Route|
|ocp_registry_source_token=${10}|OCP Source Registry Token|
|ocp_target=$6|URL API OCP Target|
|ocp_target_user=$7|OCP Target Username|
|ocp_target_pass=$8|OCP Target Password|
|ocp_registry_target=${11}|OCP Target Registry Route|
|ocp_registry_target_token=${12}|OCP Target Registry Token|
|base_dir=""|Parent direktori untuk hasil backup. Akan otomatis membuat direktori baru bernama "backup"|
|project_param=true|boolean(true/false) untuk backup/restore/verify Project|
|clusterrolebinding_param=true|boolean(true/false) untuk backup/restore/verify ClusterRoleBinding|
|image_param=true|boolean(true/false) untuk backup/restore/verify ImageStream dan ImageStreamTag|
|serviceaccount_param=true|boolean(true/false) untuk backup/restore/verify ServiceAccount|
|secret_param=true|boolean(true/false) untuk backup/restore/verify Secret|
|configmap_param=true|boolean(true/false) untuk backup/restore/verify ConfigMap|
|rolebinding_param=true|boolean(true/false) untuk backup/restore/verify RoleBinding|
|persistentvolumeclaim_param=true|boolean(true/false) untuk backup/restore/verify PersistentVolumeClaim|PersistentVolumeClaim hanya memungkinkan untuk StorageClass dengan dynamic provisioning|
|replicaset_param=true|boolean(true/false) untuk backup/restore/verify ReplicaSet|
|deployment_param=true|boolean(true/false) untuk backup/restore/verify Deployment|
|deploymentconfig_param=true|boolean(true/false) untuk backup/restore/verify DeploymentConfig|Sudah Deprecated sejak versi 4.14|
|cronjob_param=true|boolean(true/false) untuk backup/restore/verify CronJob|
|statefulset_param=true|boolean(true/false) untuk backup/restore/verify StatefulSet|
|service_param=true|boolean(true/false) untuk backup/restore/verify Service|
|route_param=true|boolean(true/false) untuk backup/restore/verify Route|
|horizontalpodautoscaler_param=true|boolean(true/false) untuk backup/restore/verify HPA|
|virtualservice_param=true|boolean(true/false) untuk backup/restore/verify VirtualService|Hanya jika menggunakan Service Mesh|
|destinationrule_param=true|boolean(true/false) untuk backup/restore/verify DestinationRule|Hanya jika menggunakan Service Mesh|
|serviceentry_param=true|boolean(true/false) untuk backup/restore/verify ServiceEntry|Hanya jika menggunakan Service Mesh|
|envoyfilter_param=true|boolean(true/false) untuk backup/restore/verify EnvoyFilter|Hanya jika menggunakan Service Mesh|
|export_helm=false|boolean(true/false) untuk menentukan apakah Secret yang dimanage oleh Helm akan diexport|
|remove_route_tls=true|boolean(true/false) menghapus .spec.tls pada Route|
|only_helm=true|boolean(true/false) untuk menentukan apakah hanya VirtualService yang dimanage oleh Helm yang akan diexport|
|patch_gateway=true|boolean(true/false) untuk mem-patch .spec.gateways pada VirtualService|
|new_gateway="istio-system/bookinfo-gateway"|Nama VirtualService atau Nama Project/Nama VirtualService|Kosongkan value ("") jika tidak mem-patch VirtualService|
|new_storageclass="ocs-external-storagecluster-ceph-rbd"|Nama StorageClass pada Cluster Target|
|bypass=true|boolean(true/false)|Untuk otomatis menginput prompt(Y/n) ketika menjalankan script restore|

### Contoh Penggunaan
```
cat migrate.conf

script_mode="verify"
projects=("jenkins-project" "app-sample" "apps-cron" "bookinfo" "app-sts")
ocp_source="https://api.cluster-njdfs.dynamic.redhatworkshops.io:6443"
ocp_source_user="admin"
ocp_source_pass="p7l5266K7z5bhMQj"
ocp_registry_source="default-route-openshift-image-registry.apps.cluster-njdfs.dynamic.redhatworkshops.io"
ocp_registry_source_token="sha256~lAgWQj8y781H7HtO38rEFqaeTlJjHTQUjYa8RtXMnAE"
ocp_target="https://api.cluster-zncmn.dynamic.redhatworkshops.io:6443/"
ocp_target_user="admin"
ocp_target_pass="fcZEdwLuSHXTs011"
ocp_registry_target="default-route-openshift-image-registry.apps.cluster-zncmn.dynamic.redhatworkshops.io"
ocp_registry_target_token="sha256~ptAzN3v2Xy2bed6l7rxBh42w6lJc1d5N4mybeXblfXA"
base_dir="/home/thinkbook/ocbc-migrate-baremetal/workload"
project_param=true
clusterrolebinding_param=true
image_param=true
serviceaccount_param=true
secret_param=true
configmap_param=true
rolebinding_param=true
persistentvolumeclaim_param=true
replicaset_param=true
deployment_param=true
replicationcontroller_param=true
deploymentconfig_param=true
cronjob_param=true
statefulset_param=true
service_param=true
route_param=true
horizontalpodautoscaler_param=true
virtualservice_param=true
destinationrule_param=true
serviceentry_param=true
envoyfilter_param=true
export_helm=false
remove_route_tls=true
only_helm=true
patch_gateway=true
new_gateway="istio-system/bookinfo-gateway"
new_storageclass="ocs-external-storagecluster-ceph-rbd"
bypass=true
```

```
./main.sh 

ATAU

./main.sh <script_mode> <satu nama project> <OCP API Source URL> <OCP Source User> <OCP Source Password> <OCP API Target URL> <OCP Target User> <OCP Target Password> <OCP Source Registry Route> <OCP Source Registry Token> <OCP Target Registry Route> <OCP Target Registry Token> <base_dir>
```

main.sh dapat digunakan dengan memberikan args ketika menjalankan script. Hal ini **tidak disarankan**, dikarenakan user dan password dapat terexpose pada bash session.

### Script Mode @migrate.conf
```
if [[ $script_mode == "backup" ]];then
        ocp_user=$ocp_source_user
        ocp_pass=$ocp_source_pass
        ocp_url=$ocp_source
elif [[ $script_mode == "restore" ]];then
        ocp_user=$ocp_target_user
        ocp_pass=$ocp_target_pass
        ocp_url=$ocp_target
fi
```
Bagian script ini akan menentukan URL API OCP, Username, dan Password ketika melakukan backup/restore.

### Bypass @main.sh
```
if [[ $bypass ]];then
        if [[ $script_mode == "restore" ]];then
                printf 'Y\n' | bash "$script" "${args_to_pass[@]}"
... omitted ...
```
Bagian script ini akan otomatis menginput "Y" pada saat menjalankan script, apabila _bypass=true_ dan apabila _script_mode=restore_. 

Ini dikarenakan, ketika menjalankan script restore, pengguna akan diminta untuk memasukkan konfirmasi berupa (Y/n).

## Backup

### General Backup Sub-script Usage

Pada dasarnya, backup script yang dipanggil melalui _main.sh_ script akan otomatis men-generate args yang diperlukan.

Apabila backup perlu dilakukan per object, pengguna dapat menggunakan backup script secara individual dengan 2 cara.

```
$ cat backup-script/backup-project.sh

config_file="/home/thinkbook/ocp-bart/ocp-bart/migrate.conf"

$ bash backup-script/backup-project.sh
```

Cara diatas adalah cara yang **direkomendasikan***, karena informasi sensitif disimpan pada file _migrate.conf_. Pengguna hanya perlu mendefinisikan path file _migrate.conf_.


```
./backup-<objek>.sh projectName ocpApiURL ocpUser ocpPass (backup boolean true|false) baseDir
./backup-<objek>.sh bookinfo https://api.cluster-rptbd.rptbd.sandbox1086.opentlc.com:6443/ opentlc-mgr MTg1OTcz true /home/thinkbook/ocbc-migrate-baremetal/workload
```

Cara ini adalah cara kedua yang sangat **tidak disarankan** dikarenakan meng-expose informasi sensitif.

Perhatikan pada spesifik dokumentasi pada script yang tersedia.

### General Backup Sub-script Breakdown

```
if [[ $<object>_param == "true" ]];then
... omitted ...
else
        echo "Skipping $obj_target"
fi
```

Jika _<object>_param=true_, maka backup objek **terkait** akan dijalankan.

```
        if [[ -f $kube_config ]];then
                current_ocp=$(oc --kubeconfig $kube_config whoami --show-server)
                current_user=$(oc --kubeconfig $kube_config whoami 2>/dev/null)
                if [[ ${current_ocp%/} != ${ocp_source%/} || $current_user == "" ]];then
                        oc login -u $ocp_user -p $ocp_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config
                fi
        else
                        oc login -u $ocp_user -p $ocp_pass $ocp_source --insecure-skip-tls-verify=true --kubeconfig $kube_config
        fi
```

Pengecekan jika file kubeconfig sudah tersedia, maka script akan memvalidasi apakah kubeconfig terkoneksi dengan URL API OCP yang benar atau user yang sedang login berbeda dengan user yang pengguna tentukan. Hal ini untuk mencegah kesalahan penggunaan file _default_ kubeconfig, dan login secara repetitif.

Bagian script ini akan melakukan login jika file kubeconfig tidak tersedia, ataupun file kubeconfig tidak terkoneksi dengan URL API OCP ataupun user yang benar.

```
if [[ "$#" -eq n ]];then
        echo "$0 <spesifik script>"
fi
```

n bergantung pada masing masing script.
Jika jumlah argument saat menjalankan script = n, maka script akan berjalan menggunakan args yang disertakan ketika memanggil sub-script.

```
elif [[ $BUILDING_ARGS ]];then
        echo "$0 projectName ocpApiURL ocpUser ocpPass projectMigrate baseDir"
        exit 0
```

Kondisi ini hanya akan berjalan jika sub-script dipanggil dari _main.sh_ script. Kondisi ini yang memberikan informasi args yang diperlukan oleh sub-script ke _main.sh_, dan akan di-generate berdasarkan variable _migrate.conf_

```
elif [[ ! -z "$config_file" && -f "$config_file" ]];then
        source "$config_file"
```

Jika kedua kondisi diatas tidak terpenuhi, misalnya saat menjalankan sub-script hanya memanggil nama script tanpa menyertakan args, dan sub-script tidak dipanggil dari _main.sh_, maka sub-script akan melakukan pengecekan variable _config\_file_ dan file _migrate.conf_, jika kondisi terpenuhi, maka file tersebut akan di-load oleh sub-script.

```
else
        echo "Define \$config_file or"
        echo "Usage: $0 projectName ocpApiURL ocpUser ocpPass projectMigrate baseDir"
        exit 1
```

Jika tidak ada kondisi yang terpenuhi, misalnya variable _config\_file_ tidak didefine pada sub-script, dan pengguna hanya memanggil sub-script tanpa menyertakan args, maka script akan memberikan helper untuk penggunaan script.

Perlu dicatat bahwa penggunaan sub-script secara individual hanya bisa dilakukan per 1 project. Jika pengguna memerlukan backup object untuk beberapa project secara sekaligus, gunakanlah file _migrate.conf_ dan definisikan variable _config\_file_.


```
function backup() {
        project_name=$1
        work_dir=$(echo $base_dir/backup/$project_name)
        echo "Backing up $obj_target $project_name"
        obj_res=$(oc --kubeconfig $kube_config get $obj_target $project_name)
        if [[ $? == 0 ]];then
                mkdir -p $(echo $work_dir)
                echo "Backing up $obj_target JSON"
                oc --kubeconfig $kube_config get $obj_target $project_name -ojson | jq -r 'del(.metadata.annotations."openshift.io/sa.scc.mcs",.metadata.annotations."openshift.io/sa.scc.supplemental-groups",.metadata.annotations."openshift.io/sa.scc.uid-range",.metadata.creationTimestamp,.metadata.labels."pod-security.kubernetes.io/audit",.metadata.labels."pod-security.kubernetes.io/audit-version",.metadata.labels."pod-security.kubernetes.io/warn",.metadata.labels."pod-security.kubernetes.io/warn-version",.metadata.resourceVersion, .metadata.uid, .spec, .status)' > $work_dir/$obj_target-$project_name.json
                echo "Result path: $work_dir/$obj_target-$project_name.json"
        else
                echo "$obj_target not found. Aborting.."
                exit 1
        fi
}
```

Script akan melakukan pengecekan objek **terkait** yang tersedia pada OCP, dengan menggunakan nama project sebagai acuan (jika object merupakan project-scoped). Jika 0, maka tidak ada yang perlu dilakukan backup.

Jika ada objek **terkait** pada OCP, maka list objek **terkait** akan dibackup dengan membuang metadata/informasi yang terkait dengan spesifik cluster seperti .metadata.uid, dan lain sebagainya, yang kemudian akan disimpan menjadi file JSON.

```
if [[ ! -z $projects && -z $project_name ]];then
                for project_name in "${projects[@]}";do
                        backup $project_name
                done
        else
                backup $project_name
        fi
```

Script akan melakukan loop terhadap projects yang didefinisikan di _migrate.conf_. Hal ini by design bertujuan untuk penggunaan sub-script secara individual per object, dengan scope multiple project, tanpa perlu menjalankan script berulang kali untuk setiap project.

Jika pengguna hanya mendefiniskan 1 project pada variable _projects_ di _migrate.conf_, maka hanya 1 project yang akan dilakukan backup. Begitupun dengan jika pengguna menggunakan sub-script secara langsung dengan menyertakan args, maka hanya 1 project yang akan dilakukan backup.

### Dokumentasi Backup Sub-script

Jika dokumentasi spesifik sub-script tidak tersedia, maka acuan penjelasan sub-script mengikuti pada bagian general. 
|Nama Script|Path Script|Docs Path|Link README|
|-----------|-----------|---------|-----------|
|backup-clusterrolebinding.sh|backup-script/backup-clusterrolebinding.sh|backup-script/docs/backup-clusterrolebinding.md|[backup-clusterrolebinding.md](backup-script/docs/backup-clusterrolebinding.md)|
|backup-configmap.sh|backup-script/backup-configmap.sh|backup-script/docs/backup-configmap.md|[backup-configmap.md](backup-script/docs/backup-configmap.md)|
|backup-image.sh|backup-script/backup-image.sh|backup-script/docs/backup-image.md|[backup-image.md](backup-script/docs/backup-image.md)|
|backup-persistentvolumeclaim.sh|backup-script/backup-persistentvolumeclaim.sh|backup-script/docs/backup-persistentvolumeclaim.md|[backup-persistentvolumeclaim.md](backup-script/docs/backup-persistentvolumeclaim.md)|
|backup-route.sh|backup-script/backup-route.sh|backup-script/docs/backup-route.md|[backup-route.md](backup-script/docs/backup-route.md)|
|backup-secret.sh|backup-script/backup-secret.sh|backup-script/docs/backup-secret.md|[backup-secret.md](backup-script/docs/backup-secret.md)|
|backup-virtualservice.sh|backup-script/backup-virtualservice.sh|backup-script/docs/backup-virtualservice.md|[backup-virtualservice.md](backup-script/docs/backup-virtualservice.md)|

### Sample Hasil Backup
```
backup
├── bookinfo
│   ├── configmap
│   ├── deployment
│   ├── envoyfilter
│   ├── horizontalpodautoscaler
│   ├── replicaset
│   ├── rolebinding
│   ├── route
│   ├── secret
│   ├── service
│   ├── serviceaccount
│   ├── serviceentry
│   └── virtualservice
├── clusterrolebinding
├── jenkins-project
│   ├── configmap
│   ├── deploymentconfig
│   ├── persistentvolumeclaim
│   ├── rolebinding
│   ├── route
│   ├── secret
│   ├── service
│   └── serviceaccount
├── test-project
│   ├── configmap
│   ├── deployment
│   ├── image
│   │   └── deployment
│   │       └── images.txt
│   ├── replicaset
│   ├── rolebinding
│   ├── route
│   ├── secret
│   ├── service
│   └── serviceaccount
└── test-sts
    ├── configmap
    ├── persistentvolumeclaim
    ├── rolebinding
    ├── secret
    ├── service
    ├── serviceaccount
    └── statefulset
```
