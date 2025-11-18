### Special Variable

|Variable|Expected Value|Remarks|
|--------|--------------|-------|
|exclude_helm=|boolean(true/false) untuk menentukan apakah VirtualService selain yang dimanage oleh Helm akan dibackup atau tidak|Perlu disesuaikan pada script ini. Tidak di-design untuk menjadi script argument untuk menghindari kesalahan dalam penggunaan|
|patch_gateway=|boolean(true/false) untuk menentukan apakah _.spec.gateway_ pada VirtualService memerlukan patch ke Gateway lain|Perlu disesuaikan pada script ini. Tidak di-design untuk menjadi script argument untuk menghindari kesalahan dalam penggunaan|
|new_gateway=|namaGateway atau namaProject/namaGateway sebagai Gateway baru pada VirtualService|Perlu disesuaikan pada script ini. Tidak di-design untuk menjadi script argument untuk menghindari kesalahan dalam penggunaan|

### Script Breakdown

```
			if [[ $exclude_helm == "true" ]];then
				has_helm_labels=$(oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r '.metadata.labels."app.kubernetes.io/managed-by" == "Helm"')
			fi
```

Jika _exclude_helm_ true, maka VirtualService akan dilakukan pengecekan terhadap label _app.kubernetes.io/managed-by_ dengan value "Helm", hasilnya berupa true/false.

Secara sederhana, _exclude_helm_ berfungsi sebagai _exclude_ selain yang dimanage oleh Helm. Penamaan variabel ini disimplifikasi berdasarkan kebutuhan tersebut.

Kenapa tidak dinamakan dengan _exclude_manual_? Karena variabel ini hanya melakukan pengecekan terhadap label key:value _app.kubernetes.io/managed-by: Helm_. Penentuan apakah VirtualService dibuat secara manual atau tidak, tidak hanya berdasarkan satu label.

```
			if [[ $exclude_helm == "true" && $has_helm_labels ]];then
				echo "Backing up $obj_target: $resource JSON"
				if [[ $patch_gateway == "true" ]];then
			       		oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r --arg ngw "$new_gateway" 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences, .status) | .spec.gateways = [$ngw]' > $work_dir/$obj_target-$resource.json
				elif [[ $patch_gateway == "false" ]];then
			       		oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences, .status)' > $work_dir/$obj_target-$resource.json
				fi
				echo "Result path: $work_dir/$obj_target-$resource.json"
```

Jika _exclude_helm_ true, maka untuk seluruh VirtualService yang memiliki label _app.kubernetes.io/managed-by_ dengan value "Helm", VirtualService tersebut akan dibackup. Jika VirtualService tidak memiliki label, ataupun value dari label tersebut bukanlah "Helm", maka VirtualService tidak akan match dengan kondisi ini.

Jika _patch_gateway_ true, maka sebelum dijadikan file JSON, manifest VirtualService akan dilakukan alter pada _.spec.gateways_ untuk ke arah Gateway yang telah ditentukan pada variabel _new_gateway_

```
			elif [[ $exclude_helm == "false" ]];then
				echo "Backing up $obj_target: $resource JSON"
				if [[ $patch_gateway == "true" ]];then
			       		oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r --arg ngw "$new_gateway" 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences, .status) | .spec.gateways = [$ngw]' > $work_dir/$obj_target-$resource.json
				elif [[ $patch_gateway == "false" ]];then
		       			oc --kubeconfig $kube_config get $obj_target $resource -n $project_name -ojson | jq -r 'del(.metadata.creationTimestamp,.metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences, .status)' > $work_dir/$obj_target-$resource.json
				fi
				echo "Result path: $work_dir/$obj_target-$resource.json"
			else
				echo "$obj_target: $resource is not Managed by Helm. Skipping"
			fi
```

Jika _exclude_helm_ false, maka seluruh VirtualService akan dibackup, tanpa memperhatikan apakah VirtualService memiliki label _app.kubernetes.io/managed-by_ atau tidak. 

Kondisi patch gateway masih sama dengan sebelumnya.

Kondisi terakhir berfungsi untuk men-handle ketika _exclude_helm_ true, tetapi VirtualService tidak memiliki label _app.kubernetes.io/managed-by_ dengan value "Helm". VirtualService tersebut akan di-skip karena tidak dimanage oleh Helm.