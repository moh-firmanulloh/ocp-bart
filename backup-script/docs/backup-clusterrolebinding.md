### Penggunaan

Apabila ingin menggunakan script ini secara inline bash, maka diperlukan argument pada saat menjalankan script.
Berikut contohnya:
```
./backup-clusterrolebinding.sh ocpApiURL ocpUser ocpPass (backup boolean true|false) baseDir
./backup-clusterrolebinding.sh https://api.cluster-rptbd.rptbd.sandbox1086.opentlc.com:6443/ opentlc-mgr MTg1OTcz true /home/thinkbook/ocbc-migrate-baremetal/workload
```

### Script Breakdown
```
        obj_res=$(oc --kubeconfig $kube_config get $obj_target -ojson | jq -r '.items[] | select((.subjects | type == "array") and any(.subjects[]?; (type == "object") and ((.kind == "User" or .kind == "Group") and (.name | test("system:*|kube-*") | not)))) | .metadata.name' | wc -l)
        if [[ "$obj_res" -ne 0 ]];then
... omitted ...
        else
                echo "$obj_target not found. Skipping"
        fi
```

Script akan melakukan pengecekan objek ClusterRoleBinding yang tersedia pada OCP, dengan memfilter User ataupun Group != system:* atau kube-*. Jika 0, maka tidak ada yang perlu dilakukan backup.

```
        obj_res=$(oc --kubeconfig $kube_config get $obj_target -ojson | jq -r '.items[] | select((.subjects | type == "array") and any(.subjects[]?; (type == "object") and ((.kind == "User" or .kind == "Group") and (.name | test("system:*|kube-*") | not)))) | .metadata.name' | wc -l)
        if [[ "$obj_res" -ne 0 ]];then
                mkdir -p $(echo $work_dir)
                oc --kubeconfig $kube_config get $obj_target -ojson | jq -r '.items[] | select((.subjects | type == "array") and any(.subjects[]?; (type == "object") and ((.kind == "User" or .kind == "Group") and (.name | test("system:*|kube-*") | not)))) | .metadata.name' | while read resource;do
                        echo "Backing up $obj_target: $resource JSON"
                        resource_file_name=$(echo $resource | tr ":" "_")
                        oc --kubeconfig $kube_config get $obj_target $resource -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .status)' > $work_dir/$obj_target-$resource_file_name.json
                        echo "Result path: $work_dir/$obj_target-$resource_file_name.json"
                done
        else
                echo "$obj_target not found. Skipping"
        fi

```

```
'.items[] | 
        select(
                (.subjects | type == "array") and 
                        any(.subjects[]?; (type == "object") and 
                        (
                                (.kind == "User" or .kind == "Group") and (.name | test("system:*|kube-*") | not)
                        )
                )
        ) 
        | .metadata.name'
```

Pada bagian ini, jq akan memilih ClusterRoleBinding yang memiliki _.subjects_ dengan tipe _array_, dan apapun isi dari _array_ _.subjects_ yang bertipe _object_, dan object tersebut memiliki _.kind_ dengan value "User" atau "group", yang dengan nama yang bukan mengandung "system:*" ataupun "kube:-*"

Jika ada objek ClusterRoleBinding pada OCP, maka list ClusterRoleBinding yang sudah difilter akan dibackup dengan membuang metadata/informasi yang terkait dengan spesifik cluster seperti .metadata.uid, dan lain sebagainya, yang kemudian akan disimpan menjadi file JSON.

Dikarenakan nama ClusterRoleBinding digunakan sebagai referensi untuk menyimpan ke file JSON, dan ClusterRoleBinding memungkinkan dengan penamaan menggunakan simbol ":", dan linux tidak bisa menyimpan file dengan simbol tersebut, maka nama yang mengandung simbol ":" akan otomatis diubah menjadi "_".