### Special Variable

Special Variable perlu didefinisikan pada _migrate.conf_, atau inline bash.

### Penggunaan

Apabila ingin menggunakan script ini secara inline bash, maka diperlukan argument pada saat menjalankan script.
Berikut contohnya:
```
./backup-persistentvolumeclaim.sh projectName ocpApiURL ocpUser ocpPass (backup boolean true|false) baseDir newStorageClass
./backup-persistentvolumeclaim.sh bookinfo https://api.cluster-rptbd.rptbd.sandbox1086.opentlc.com:6443/ opentlc-mgr MTg1OTcz true /home/thinkbook/ocbc-migrate-baremetal/workload ocs-external-storagecluster-ceph-rbd
```

### Script Breakdown

```

                        oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r --arg nsc "$new_storageclass" 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .metadata.finalizers, .spec.volumeName, .status) | .spec.storageClassName = $nsc' > $work_dir/$obj_target-$resource.json
```

Pada bagian script ini akan melakukan replace pada _.spec.storageClassname_ menggunakan value dari _$new_storageclass_.