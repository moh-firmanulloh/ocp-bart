### Penggunaan

Apabila ingin menggunakan script ini secara inline bash, maka diperlukan argument pada saat menjalankan script.
Berikut contohnya:
```
./backup-project.sh projectName ocpApiURL ocpUser ocpPass (backup boolean true|false) baseDir
./backup-project.sh bookinfo https://api.cluster-rptbd.rptbd.sandbox1086.opentlc.com:6443/ opentlc-mgr MTg1OTcz true /home/thinkbook/ocbc-migrate-baremetal/workload

### Script Breakdown

```
		oc --kubeconfig $kube_config get $obj_target $project_name -ojson | jq -r 'del(.metadata.annotations."openshift.io/sa.scc.mcs",.metadata.annotations."openshift.io/sa.scc.supplemental-groups",.metadata.annotations."openshift.io/sa.scc.uid-range",.metadata.creationTimestamp,.metadata.labels."pod-security.kubernetes.io/audit",.metadata.labels."pod-security.kubernetes.io/audit-version",.metadata.labels."pod-security.kubernetes.io/warn",.metadata.labels."pod-security.kubernetes.io/warn-version",.metadata.resourceVersion, .metadata.uid, .spec, .status)'
```

Pada bagian script ini akan melakukan penghapusan beberapa metadata yang by-default di-generate oleh OpenShift.
```
metadata:
  annotations:
    "openshift.io/sa.scc.mcs":
    "openshift.io/sa.scc.supplemental-groups":
    "openshift.io/sa.scc.uid-range":
  creationTimestamps:
  labels:
    "pod-security.kubernetes.io/audit":
    "pod-security.kubernetes.io/audit-version":
    "pod-security.kubernetes.io/warn":
    "pod-security.kubernetes.io/warn-version":
  resourceVersion:
  uid:
spec:
status:
```