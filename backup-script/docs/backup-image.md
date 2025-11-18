### Penggunaan

Apabila ingin menggunakan script ini secara inline bash, maka diperlukan argument pada saat menjalankan script.
Berikut contohnya:
```
./backup-image.sh projectName ocpApiURL ocpUser ocpPass (backup boolean true|false) baseDir
./backup-image.sh bookinfo https://api.cluster-rptbd.rptbd.sandbox1086.opentlc.com:6443/ opentlc-mgr MTg1OTcz true /home/thinkbook/ocbc-migrate-baremetal/workload
```

### Script Breakdown
```
function img_pattern_non_cj {
        container_num=$1
        oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r --arg n "$container_num" '.spec.template.spec.containers[$n|tonumber].image'
}
```

Fungsi ini digunakan untuk mengambil value _image:_ pada setiap objek kontroller aplikasi, selain CronJob. Fungsi ini menggunakan referensi nomor container pada array, dikarenakan adanya potensi multi-container (tidak termasuk sidecar inject) pada sebuah kontroller aplikasi.

```
function img_pattern_cj {
        container_num=$1
        oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r --arg n "$container_num" '.spec.jobTemplate.spec.template.spec.containers[$n|tonumber].image'
}
```

Fungsi ini digunakan untuk mengambil value _image:_ pada CronJob. CronJob memiliki path _image:_ yang berbeda dibandingkan dengan kontroller aplikasi lainnya. Fungsi ini menggunakan referensi nomor container pada array, dikarenakan adanya potensi multi-container (tidak termasuk sidecar inject) pada sebuah kontroller aplikasi.

```
function img_result {
        img_pattern=$1
        full_pattern=$(echo $img_pattern | tr -dc '/' | wc -c)
        repo_name=$(echo $img_pattern | cut -d"/" -f1)
        img_project=$(echo $img_pattern | cut -d"/" -f2)
        digest=$(echo $img_pattern | grep -o '@sha256:[a-f0-9]\+')
        if [ "$full_pattern" -eq 2 ];then
                if [[ $repo_name == "image-registry.openshift-image-registry.svc:5000" && $img_project != "openshift" ]];then
                        if [[ "$digest" == *@sha256:* ]];then
                                tag=$(oc --kubeconfig $kube_config get imagestream -n $project_name -ojson | jq -r --arg d "$digest" '.items[] | {name: .metadata.name, tag: (.status.tags[]? | select(.items[].dockerImageReference | endswith($d)) | .tag)} | select(.tag != null) | .tag')
                                imagestream=$(echo $img_pattern | cut -d"/" -f3 | cut -d"@" -f1)
                                img_name=$(echo "$imagestream:$tag")
                                echo $img_name >> $work_dir/$obj_target/images.txt
                        else
                                img_name=$(echo $img_pattern | cut -d"/" -f3)
                                echo $img_name >> $work_dir/$obj_target/images.txt
                        fi
                elif [[ $img_project == "openshift" || $repo_name != "image-registry.openshift-image-registry.svc:5000" ]];then
                        echo "Putting $obj_target: $resource image as non migrated"
                        echo "$project_name,$resource,$img_pattern" >> $work_dir/$obj_target/non-migrated.txt
                fi
        else
                echo "Putting $obj_target: $resource image as non migrated"
                echo "$project_name,$resource,$img_pattern" >> $work_dir/$obj_target/non-migrated.txt
        fi
}

```

Fungsi ini untuk menentukan apakah referensi _image:_ pada kontroller aplikasi mengarah ke internal image registry OCP (image-registry.openshift-image-registry.svc:5000).

Jika pada kontroller aplikasi menggunakan image hash/digest, maka fungsi ini akan mencarikan tag sesuai dengan hash/digest tersebut. 

Untuk setiap image yang sesuai dengan kondisi diatas, maka akan dimasukkan ke dalam file images.txt dengan pattern _ImageStream:ImageStreamTag_.

Untuk referensi _image:_ yang tidak mengarah ke internal image registry OCP, maka akan di masukkan ke dalam file non-migrated.txt