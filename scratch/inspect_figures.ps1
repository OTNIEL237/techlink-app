$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open((Resolve-Path 'scratch\test_doc.doc').Path)
for ($i = 1; $i -le $doc.Paragraphs.Count; $i++) {
    $p = $doc.Paragraphs.Item($i)
    if ($p.Range.Text -match "LISTE\s*DES\s*FIGURES") {
        for ($j = [Math]::Max(1, $i - 5); $j -lt $i; $j++) {
            $prevP = $doc.Paragraphs.Item($j)
            $txt = $prevP.Range.Text.Trim()
            Write-Output ("Prev {0} : '{1}'" -f $j, $txt)
        }
        $t = $p.Range.Text.Trim()
        Write-Output ("Found at {0} : '{1}'" -f $i, $t)
        break
    }
}
$doc.Close($false)
$word.Quit()
