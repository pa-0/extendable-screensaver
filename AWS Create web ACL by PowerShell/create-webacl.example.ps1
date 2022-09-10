$RegionName = "eu-west-1";
$ResourceARN = "arn:aws:elasticloadbalancing:$($RegionName):123456789012:loadbalancer/app/load-balancer-EXAMPLE/0123456789abcdef";

$result = .\create-webacl.ps1 `
    -resourcearn $ResourceARN `
    -rulesfilename "webacl-rules.json" `
    -tagname 'Blog' `
    -tagnameprefix 'blog' `
    -regionname $RegionName `
    -verbose;

if ((-not $?) -or (-not $result)) {
    Write-Error "Web ACL or related resources are not created";
}
