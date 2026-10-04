$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open((Resolve-Path 'scratch\test_doc.doc').Path)
for ($i = 60; $i -le $doc.Paragraphs.Count; $i++) {
    $p = $doc.Paragraphs.Item($i)
    if ($p.Range.Text -match "LISTE\s*DES\s*FIGURES" -and $p.Range.Text -notmatch "\t") {
        for ($j = [Math]::Max(1, $i - 8); $j -lt $i; $j++) {
            $prevP = $doc.Paragraphs.Item($j)
            $txt = $prevP.Range.Text.Trim()
            Write-Output ("Prev {0} : '{1}'" -f $j, $txt)
        }
        $t = $p.Range.Text.Trim()
        Write-Output ("Found Heading at {0} : '{1}'" -f $i, $t)
        # Also print next 5
        for ($k = $i + 1; $k -le [Math]::Min($doc.Paragraphs.Count, $i + 5); $k++) {
            $nextP = $doc.Paragraphs.Item($k)
            Write-Output ("Next {0} : '{1}'" -f $k, $nextP.Range.Text.Trim())
        }
        break
    }
}
$doc.Close($false)
$word.Quit()
