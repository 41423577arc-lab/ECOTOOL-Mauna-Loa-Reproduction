param(
    [string]$InputDocument = 'outputs/A_B_C三份数据_ARIMA预测综合报告.docx',
    [string]$OutputFolder = 'work/three_arima_render'
)
$ErrorActionPreference = 'Stop'
$documentPath = (Resolve-Path -LiteralPath $InputDocument).Path
$renderPath = Join-Path (Get-Location).Path $OutputFolder
if (-not (Test-Path -LiteralPath $renderPath)) { [void](New-Item -ItemType Directory -Path $renderPath) }
$pdfPath = Join-Path $renderPath 'report.pdf'
$wordApp = $null
$wordDocument = $null
$hadDocuments = $true
try {
    $wordApp = New-Object -ComObject Word.Application
    $hadDocuments = $wordApp.Documents.Count -gt 0
    if (-not $hadDocuments) { $wordApp.Visible = $false }
    $previousAlerts = $wordApp.DisplayAlerts
    $wordApp.DisplayAlerts = 0
    $wordDocument = $wordApp.Documents.Open($documentPath, $false, $true, $false)
    $wordDocument.Repaginate()
    $pages = $wordDocument.ComputeStatistics(2)
    $wordDocument.ExportAsFixedFormat($pdfPath, 17)
    Write-Output "Rendered $pages pages to $pdfPath"
}
finally {
    if ($null -ne $wordDocument) { $wordDocument.Close(0); [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wordDocument) }
    if ($null -ne $wordApp) {
        $wordApp.DisplayAlerts = $previousAlerts
        if (-not $hadDocuments) { $wordApp.Quit() }
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wordApp)
    }
}
