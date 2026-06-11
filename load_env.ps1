Get-Content .env | ForEach-Object {
    # 跳過空行和註解行
    if ($_ -match '^\s*$' -or $_ -match '^\s*#') { return }
    $name, $value = $_.Split('=', 2)
    Set-Item -Path "env:$name" -Value $value
}