### Special Variable

Special Variable perlu didefinisikan pada _migrate.conf_, atau inline bash.

### Penggunaan

Apabila ingin menggunakan script ini secara inline bash, maka diperlukan argument pada saat menjalankan script.
Berikut contohnya:
```
./backup-route.sh projectName ocpApiURL ocpUser ocpPass (backup boolean true|false) baseDir (remove_cert boolean true|false)
./backup-route.sh bookinfo https://api.cluster-rptbd.rptbd.sandbox1086.opentlc.com:6443/ opentlc-mgr MTg1OTcz true /home/thinkbook/ocbc-migrate-baremetal/workload true
```

### Script Breakdown

Script akan melakukan pengecekan objek Route yang tersedia pada OCP. Jika 0, maka tidak ada yang perlu dilakukan backup.

```
                mkdir -p $(echo $work_dir)
                oc --kubeconfig $kube_config get $obj_target -n $project_name --no-headers | awk '{print $1}' | while read resource;do
                        echo "Backing up $obj_target: $resource JSON"
                        if [[ $remove_cert ]];then
                                oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences, .status, .metadata.generation, .spec.tls)' > $work_dir/$obj_target-$resource.json
                        elif [[ ! $remove_cert ]];then
                                oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences, .status, .metadata.generation)' > $work_dir/$obj_target-$resource.json
                        fi
                        echo "Result path: $work_dir/$obj_target-$resource.json"
                done
```

Jika ada objek Route pada OCP, maka jika _remove_cert=true_, maka bagian _.spec.tls_ pada Route akan dibuang, termasuk dengan metadata/informasi yang terkait dengan spesifik cluster seperti .metadata.uid, dan lain sebagainya, yang kemudian akan disimpan menjadi file JSON.
Sebaliknya, jika _remove_cert=false_, maka bagian _.spec.tls_ akan dipertahankan jika ada dan membuang metadata/informasi yang terkait dengan spesifik cluster, sebelum disimpan menjadi file JSON.