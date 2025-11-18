### Special Variable

|Variable|Expected Value|Remarks|
|--------|--------------|-------|
|exclude_pattern="^openshift\|^kube"|RegEx pattern untuk men-exclude ConfigMap yang tidak diinginkan|Secara default, setiap project memiliki beberapa ConfigMap yang terbuat secara otomatis. Apabila terdapat Operator yang terinstall, ada kemungkinan bahwa default ConfigMap yang dibuat secara otomatis jumlahnya lebih banyak.|

### Penggunaan

Apabila ingin menggunakan script ini secara inline bash, maka diperlukan argument pada saat menjalankan script.
Berikut contohnya:
```
./backup-configmap.sh projectName ocpApiURL ocpUser ocpPass (backup boolean true|false) baseDir
./backup-configmap.sh bookinfo https://api.cluster-rptbd.rptbd.sandbox1086.opentlc.com:6443/ opentlc-mgr MTg1OTcz true /home/thinkbook/ocbc-migrate-baremetal/workload
```

### Script Breakdown
```
        obj_res=$(oc --kubeconfig $kube_config get $obj_target -n $project_name --no-headers | egrep -v $(echo $exclude_pattern) | wc -l)
        if [[ "$obj_res" -ne 0 ]];then
... omitted ...
        else
                echo "$obj_target not found. Skipping"
        fi
```

Script akan melakukan pengecekan objek ConfigMap yang tersedia pada OCP, dengan memfilter sesuai _$exclude_pattern_. Jika 0, maka tidak ada yang perlu dilakukan backup.

```
        obj_res=$(oc --kubeconfig $kube_config get $obj_target -n $project_name --no-headers | egrep -v $(echo $exclude_pattern) | wc -l)
        if [[ "$obj_res" -ne 0 ]];then
                mkdir -p $(echo $work_dir)
                oc --kubeconfig $kube_config get $obj_target -n $project_name --no-headers | egrep -v $(echo $exclude_pattern) | awk '{print $1}' | while read resource;do
                        echo "Backing up $obj_target: $resource JSON"
                        resource_file_name=$(echo $resource | tr ":" "_")
                        oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences, .status)' > $work_dir/$obj_target-$resource_file_name.json
                        echo "Result path: $work_dir/$obj_target-$resource_file_name.json"
                done
        else
                echo "$obj_target not found. Skipping"
        fi
```

Jika ada objek ConfigMap pada OCP, maka list ConfigMap yang sudah difilter akan dibackup dengan membuang metadata/informasi yang terkait dengan spesifik cluster seperti .metadata.uid, dan lain sebagainya, yang kemudian akan disimpan menjadi file JSON.

Dikarenakan nama ConfigMap digunakan sebagai referensi untuk menyimpan ke file JSON, dan ConfigMap memungkinkan dengan penamaan menggunakan simbol ":", dan linux tidak bisa menyimpan file dengan simbol tersebut, maka nama yang mengandung simbol ":" akan otomatis diubah menjadi "_".