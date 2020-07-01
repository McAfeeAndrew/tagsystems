# example:
# curl -qk -u username:password https://1.2.3.4:8443/remote/system.importTag -F "uploadFile=@<path_to_file>"

#
# Replace the following with 
#
$epohost = "1.2.3.4"
$epoport = 8443
$user = "username"
$password = "password"
$FilePath = 'c:\temp\systemtags.csv';

#
# start by trusting the self-signed ePO cert
#
function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    ## We create an instance of TrustAll and attach it to the ServicePointManager
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}
Ignore-SSLCertificates

#
# Build the url, creds and set TLS1.2
#
$url = "https://" + $epohost + ":" + $epoport + "/remote/system.importTag"
$creds = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($user + ':' + $password))
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
 
#
# build the multi-part form submission
#
$fileBytes = [System.IO.File]::ReadAllBytes($FilePath);
$fileEnc = [System.Text.Encoding]::GetEncoding('UTF-8').GetString($fileBytes);
$boundary = [System.Guid]::NewGuid().ToString();
$LF = "`r`n";
 
$bodyLines = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"file`"; filename=`"systemtags.csv`"",
    "Content-Type: application/vnd.ms-excel$LF",
    $fileEnc,
    "--$boundary--$LF"
) -join $LF

#
# make the call
#
Invoke-RestMethod -Uri $url -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines
 
