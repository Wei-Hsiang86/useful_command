Get-Content .env | ForEach-Object {
    $name, $value = $_.Split('=')
    Set-Item -Path "env:$name" -Value $value
}