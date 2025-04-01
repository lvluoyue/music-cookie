# �ýű�ʹ��GB2312����
$OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName Microsoft.PowerShell.Commands.Utility
# �ر�curl������ʾ
$ProgressPreference = 'SilentlyContinue'

function Invoke-Request {
    param (
        [string]$Uri,
        [hashtable]$Headers,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession = $null,
        [int]$Timeout = 30
    )
    try {
        return Invoke-WebRequest -Uri $Uri -Method Get `
            -UseBasicParsing `
            -DisableKeepAlive `
            -Headers $Headers `
            -WebSession $WebSession `
            -TimeoutSec $Timeout `
            -ErrorAction Stop
    } catch {
        if($_.Exception -match "The operation has timed out") {
            Write-Host "����ʱ��������������" -ForegroundColor Red
        }else {
            Write-Host "����ʧ�ܣ�������Ϣ:" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
        Exit ;
    }
}

function Get-CookieValue {
    param (
        [string[]]$Cookies,
        [string]$CookieName
    )
    $cookie = $Cookies | Where-Object { $_ -match "$CookieName=([^;]+)" }
    if ($cookie -and $matches[1]) {
        return $matches[1]
    }
    return $null
}

try {
    Write-Host "�ű����������ڵ�¼..." -ForegroundColor Green

    # Ŀ��URL��ַ��ԭʼ��ʽ
    $targetUrl = "https://xui.ptlogin2.qq.com/cgi-bin/xlogin?appid=716027609&daid=383&style=33&login_text=%E7%99%BB%E5%BD%95&hide_title_bar=1&hide_border=1&target=self&s_url=https%3A%2F%2Fgraph.qq.com%2Foauth2.0%2Flogin_jump&pt_3rd_aid=100497308&pt_feedback_link=https%3A%2F%2Fsupport.qq.com%2Fproducts%2F77942%3FcustomInfo%3D.appid100497308&theme=2&verify_theme="
    $refererHeaders = @{"Referer" = $targetUrl}

    # ����GET�����Զ�������Ӧ
    $response = Invoke-Request -Uri $targetUrl

    # ��ȡĿ��Cookie
    $pt_local_token = Get-CookieValue -Cookies $response.Headers['Set-Cookie'] -CookieName "pt_local_token"
    if (-not $pt_local_token) {
        Write-Host "δ�ܳɹ���ȡ pt_local_token Cookieֵ" -ForegroundColor Red
        Exit ;
    }

    Write-Host "�ɹ���ȡ pt_local_token: $pt_local_token" -ForegroundColor Green

    $getUinsUrl = "https://localhost.ptlogin2.qq.com:4301/pt_get_uins?callback=ptui_getuins_CB&r=0.9038523633869937&pt_local_tk=$pt_local_token"


    # ����WebSession�������Cookie
    $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $cookieObj = New-Object System.Net.Cookie("pt_local_token", $pt_local_token, "/", "localhost.ptlogin2.qq.com")
    $webSession.Cookies.Add($cookieObj)

    $newResponse = Invoke-Request -Uri $getUinsUrl -Headers $refererHeaders -WebSession $webSession

    # ������Ӧ�����е� var_sso_uin_list
    $responseContent = $newResponse.Content
    if (-not ($responseContent -match 'var var_sso_uin_list=(\[.*?\]);')) {
        Write-Host "δ�ܷ�����Ч���û��б�" -ForegroundColor Red
        Exit ;
    }

    $userList = ConvertFrom-Json $matches[1]

    # ��ʾ�û��б����û�ѡ��
    Write-Host "��ѡ��һ���û�:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $userList.Length; $i++) {
        Write-Host "[$i] �˺�: $($userList[$i].uin)"
    }
    $userChoice = Read-Host "�������û����"

    if (-not ($userChoice -match '^\d+$') -or [int]$userChoice -lt 0 -or [int]$userChoice -ge $userList.Length) {
        Write-Host "��Ч��ѡ��" -ForegroundColor Red
        Exit ;
    }

    $selectedUser = $userList[$userChoice]

    # �����µ�����
    $newRequestUrl = "https://localhost.ptlogin2.qq.com:4301/pt_get_st?clientuin=$($selectedUser.uin)&r=0.5287717305315094&pt_local_tk=$pt_local_token&callback=__jp0"

    $newRequestResponse = Invoke-Request -Uri $newRequestUrl -Headers $refererHeaders -WebSession $webSession

    # ��ȡCookie
    $newCookieCollection = $newRequestResponse.Headers['Set-Cookie']
    $clientuin = Get-CookieValue -Cookies $newCookieCollection -CookieName "clientuin"
    $clientkey = Get-CookieValue -Cookies $newCookieCollection -CookieName "clientkey"

    if (-not $clientuin -or -not $clientkey) {
        Write-Host "δ�ܷ�����Ч��clientuin��clientkey" -ForegroundColor Red
        Exit ;
    }

    Write-Host "clientuin: $clientuin" -ForegroundColor Green
    Write-Host "clientkey: $clientkey" -ForegroundColor Green
}
finally {
    # �ָ�Ĭ�ϵĽ�����ʾ
    $ProgressPreference = 'Continue'

    Write-Host "��������˳�����" 
    [Console]::Read() | Out-Null ;
    Exit ;
}