[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing

function Render-ClassDiagram {
    param([string]$outputPath, [float]$scale = 2.0)

    $width = [int](1550 * $scale)
    $height = [int](1280 * $scale)

    $bmp = New-Object System.Drawing.Bitmap ($width), ($height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)

    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Fond blanc pur
    $g.Clear([System.Drawing.Color]::White)

    # Styles et palettes de couleurs UML
    $boxFill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 235, 255))
    $headerFill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(170, 215, 255))
    $boxBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(0, 102, 204)), ([float](2.0 * $scale))
    $divBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(0, 102, 204)), ([float](1.2 * $scale))
    $assocPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(0, 85, 170)), ([float](1.8 * $scale))
    
    $titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 34, 68))
    $stereoBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 68, 136))
    $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 20, 40))
    $labelBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 51, 120))
    $multiBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 40, 90))
    $badgeBg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(242, 248, 255))
    $badgeBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(130, 185, 245)), ([float](1.0 * $scale))

    # Polices nettes et précises
    $fontTitle = New-Object System.Drawing.Font ("Segoe UI", (13.5 * $scale), [System.Drawing.FontStyle]::Bold)
    $fontStereo = New-Object System.Drawing.Font ("Segoe UI", (9.5 * $scale), [System.Drawing.FontStyle]::Italic)
    $fontMono = New-Object System.Drawing.Font ("Consolas", (10.8 * $scale), [System.Drawing.FontStyle]::Regular)
    $fontLabel = New-Object System.Drawing.Font ("Segoe UI", (9.2 * $scale), [System.Drawing.FontStyle]::Bold)
    $fontMulti = New-Object System.Drawing.Font ("Segoe UI", (9.5 * $scale), [System.Drawing.FontStyle]::Bold)

    $formatCenter = New-Object System.Drawing.StringFormat
    $formatCenter.Alignment = [System.Drawing.StringAlignment]::Center
    $formatCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

    $formatLeft = New-Object System.Drawing.StringFormat
    $formatLeft.Alignment = [System.Drawing.StringAlignment]::Near
    $formatLeft.LineAlignment = [System.Drawing.StringAlignment]::Near

    # Tracé d'une boîte de classe UML
    $DrawBox = {
        param($x, $y, $w, $h, $title, $stereo, [string[]]$attrs, [string[]]$methods)
        $rx = [float]($x * $scale)
        $ry = [float]($y * $scale)
        $rw = [float]($w * $scale)
        $rh = [float]($h * $scale)
        $headerH = [float]($(if ($stereo) { 34.0 * $scale } else { 25.0 * $scale }))

        # Fond et en-tête
        $g.FillRectangle($boxFill, $rx, $ry, $rw, $rh)
        $g.FillRectangle($headerFill, $rx, $ry, $rw, $headerH)
        $g.DrawRectangle($boxBorder, $rx, $ry, $rw, $rh)
        $g.DrawLine($divBorder, $rx, ($ry + $headerH), ($rx + $rw), ($ry + $headerH))

        # Titre et stéréotype
        if ($stereo) {
            $g.DrawString($title, $fontTitle, $titleBrush, ($rx + $rw/2), ($ry + 12.0 * $scale), $formatCenter)
            $g.DrawString($stereo, $fontStereo, $stereoBrush, ($rx + $rw/2), ($ry + 25.0 * $scale), $formatCenter)
        } else {
            $g.DrawString($title, $fontTitle, $titleBrush, ($rx + $rw/2), ($ry + $headerH/2), $formatCenter)
        }

        # Attributs
        $currY = $ry + $headerH + 5.0 * $scale
        $lineStep = 15.0 * $scale
        foreach ($a in $attrs) {
            $g.DrawString($a, $fontMono, $textBrush, ($rx + 8.0 * $scale), $currY, $formatLeft)
            $currY += $lineStep
        }

        # Séparateur méthodes si présent
        if ($methods -and $methods.Length -gt 0) {
            $currY += 2.0 * $scale
            $g.DrawLine($divBorder, $rx, $currY, ($rx + $rw), $currY)
            $currY += 5.0 * $scale
            foreach ($m in $methods) {
                $g.DrawString($m, $fontMono, $textBrush, ($rx + 8.0 * $scale), $currY, $formatLeft)
                $currY += $lineStep
            }
        }
    }

    # Tracé d'une association
    $DrawAssoc = {
        param([float[]]$points, $label, $m1, $m2, [float[]]$m1Pos, [float[]]$m2Pos, [float[]]$lblPos)
        for ($i = 0; $i -lt ($points.Length - 2); $i += 2) {
            $x1 = [float]($points[$i] * $scale)
            $y1 = [float]($points[$i+1] * $scale)
            $x2 = [float]($points[$i+2] * $scale)
            $y2 = [float]($points[$i+3] * $scale)
            $g.DrawLine($assocPen, $x1, $y1, $x2, $y2)
        }
        if ($label -and $lblPos) {
            $lx = [float]($lblPos[0] * $scale)
            $ly = [float]($lblPos[1] * $scale)
            $size = $g.MeasureString($label, $fontLabel)
            $lw = [float]($size.Width + 12.0 * $scale)
            $lh = [float](16.0 * $scale)
            $g.FillRectangle($badgeBg, ($lx - $lw/2), ($ly - $lh/2), $lw, $lh)
            $g.DrawRectangle($badgeBorder, ($lx - $lw/2), ($ly - $lh/2), $lw, $lh)
            $g.DrawString($label, $fontLabel, $labelBrush, $lx, $ly, $formatCenter)
        }
        if ($m1 -and $m1Pos) {
            $g.DrawString($m1, $fontMulti, $multiBrush, ($m1Pos[0] * $scale), ($m1Pos[1] * $scale), $formatLeft)
        }
        if ($m2 -and $m2Pos) {
            $g.DrawString($m2, $fontMulti, $multiBrush, ($m2Pos[0] * $scale), ($m2Pos[1] * $scale), $formatLeft)
        }
    }

    # Tracé d'un héritage avec triangle creux
    $DrawInheritance = {
        param([float[]]$points, [string]$dir = "right")
        for ($i = 0; $i -lt ($points.Length - 2); $i += 2) {
            $x1 = [float]($points[$i] * $scale)
            $y1 = [float]($points[$i+1] * $scale)
            $x2 = [float]($points[$i+2] * $scale)
            $y2 = [float]($points[$i+3] * $scale)
            $g.DrawLine($assocPen, $x1, $y1, $x2, $y2)
        }
        $endX = [float]($points[$points.Length - 2] * $scale)
        $endY = [float]($points[$points.Length - 1] * $scale)
        
        $tPts = @()
        if ($dir -eq "right") {
            $tPts = @(
                (New-Object System.Drawing.PointF($endX, $endY)),
                (New-Object System.Drawing.PointF(($endX - 12.0*$scale), ($endY - 6.0*$scale))),
                (New-Object System.Drawing.PointF(($endX - 12.0*$scale), ($endY + 6.0*$scale)))
            )
        } elseif ($dir -eq "up") {
            $tPts = @(
                (New-Object System.Drawing.PointF($endX, $endY)),
                (New-Object System.Drawing.PointF(($endX - 6.0*$scale), ($endY + 12.0*$scale))),
                (New-Object System.Drawing.PointF(($endX + 6.0*$scale), ($endY + 12.0*$scale)))
            )
        }
        $g.FillPolygon([System.Drawing.Brushes]::White, $tPts)
        $g.DrawPolygon($assocPen, $tPts)
    }

    # ================= 1. TRACÉ DES ASSOCIATIONS & HÉRITAGES =================
    
    # Héritages vers Utilisateur
    &$DrawInheritance @(460, 235, 740, 235) "right"
    &$DrawInheritance @(700, 350, 740, 350) "right"
    &$DrawInheritance @(870, 490, 870, 440) "up"

    # Associations
    &$DrawAssoc @(865, 160, 865, 210) "APPELER" "0..*" "1..1" @(835, 170) @(835, 192) @(905, 185)
    &$DrawAssoc @(990, 280, 1150, 280) "RECEVOIR" "1..1" "0..*" @(995, 262) @(1115, 262) @(1070, 275)
    &$DrawAssoc @(990, 400, 1220, 400) "ENVOYER" "1..1" "0..*" @(995, 382) @(1185, 382) @(1105, 395)
    &$DrawAssoc @(1010, 615, 1150, 615) "CONSULTER" "1..1" "1..1" @(1015, 597) @(1115, 597) @(1080, 610)
    &$DrawAssoc @(350, 290, 350, 415) "OUVRIR" "1..1" "0..*" @(320, 305) @(320, 395) @(375, 352)
    &$DrawAssoc @(460, 370, 400, 370, 400, 415) "RESOUDRE" "1..1" "1..1" @(435, 355) @(405, 400) @(370, 370)
    &$DrawAssoc @(470, 470, 730, 470, 730, 550, 750, 550) "OUVRIR" "0..*" "1..1" @(475, 452) @(735, 535) @(600, 465)
    &$DrawAssoc @(240, 260, 210, 260, 210, 560, 495, 560) "DONNER" "1..1" "0..*" @(215, 245) @(460, 545) @(235, 410)
    &$DrawAssoc @(730, 590, 750, 590) "OBTENIR" "0..*" "1..1" @(705, 572) @(735, 572) @(740, 560)
    &$DrawAssoc @(530, 650, 530, 675, 450, 675, 450, 700) "CONCERNER" "0..*" "1..1" @(535, 655) @(455, 685) @(490, 675)
    &$DrawAssoc @(330, 575, 330, 700) "DECLENCHER" "0..*" "1..1" @(300, 590) @(300, 685) @(355, 637)
    &$DrawAssoc @(240, 210, 90, 210, 90, 700) "EFFECTUER" "1..1" "0..*" @(145, 195) @(95, 680) @(65, 455)
    &$DrawAssoc @(235, 760, 270, 760) "FACTURER" "0..*" "1..1" @(238, 742) @(252, 742) @(252, 725)
    &$DrawAssoc @(110, 840, 110, 1030, 150, 1030) "NECESSITER" "0..*" "1..1" @(115, 855) @(125, 1012) @(65, 935)
    &$DrawAssoc @(535, 830, 700, 830) "REGROUPER" "0..*" "1..1" @(545, 812) @(665, 812) @(617, 825)
    &$DrawAssoc @(535, 730, 750, 730) "CREER" "0..*" "1..1" @(545, 712) @(715, 712) @(642, 725)
    &$DrawAssoc @(410, 955, 410, 1020, 480, 1020) "GENERER" "1..1" "0..*" @(380, 970) @(450, 1005) @(410, 990)
    &$DrawAssoc @(700, 1010, 830, 1010, 830, 760) "RECEVOIR" "0..*" "1..1" @(705, 992) @(835, 780) @(765, 1005)
    &$DrawAssoc @(910, 760, 910, 1030) "PROPOSER" "1..1" "0..*" @(915, 780) @(915, 1010) @(935, 895)
    &$DrawAssoc @(700, 1060, 830, 1060) "" "0..*" "1..1" @(705, 1042) @(795, 1042) @()
    &$DrawAssoc @(850, 1140, 850, 1170, 260, 1170, 260, 1130) "APPARTENIR" "0..*" "1..1" @(815, 1150) @(265, 1140) @(555, 1170)
    &$DrawAssoc @(950, 1140, 950, 1210, 50, 1210, 50, 840) "ENGENDRER" "1..1" "0..*" @(915, 1150) @(55, 855) @(500, 1210)

    # ================= 2. TRACÉ DES BOÎTES DE CLASSES =================

    &$DrawBox 750 30 230 130 "Appel" "" @(
        "- id : int",
        "- id_appel_externe : String",
        "- statut : String",
        "- date_creation : Date"
    ) @(
        "+ demarrerAppel() : void",
        "+ terminerAppel() : void"
    )

    &$DrawBox 740 210 250 230 "Utilisateur" "<<abstract>>" @(
        "- telephone : String",
        "- nom : String",
        "- role : String",
        "- photoProfilUrl : String",
        "- estBanni : Boolean",
        "- date_creation : Date",
        "- statut : String"
    ) @(
        "+ s'authentifier() : void",
        "+ mettreAJourProfil() : void",
        "+ seDeconnecter() : void"
    )

    &$DrawBox 240 180 220 110 "client" "" @(
        "- id_client : int"
    ) @(
        "+ creerMission() : void",
        "+ accepterDevis() : Boolean",
        "+ payerMission() : Boolean"
    )

    &$DrawBox 460 305 240 95 "Administrateur" "" @(
        "- id_admin : int"
    ) @(
        "+ verifierDocument() : void",
        "+ suspendreUtilisateur() : void"
    )

    &$DrawBox 750 490 260 270 "Technicien" "" @(
        "- id_technicien : String",
        "- annees_experience : int",
        "- specialties : String",
        "- rayon_zone_km : String",
        "- statut_disponibilite : String",
        "- statut_validation : String",
        "- total_missions : int",
        "- moyenne_notes : Double",
        "- solde_portefeuille : Double"
    ) @(
        "+ mettreAJourPosition() : void",
        "+ accepterDemandeMission() : void",
        "+ soumettreDevis() : void"
    )

    &$DrawBox 1150 220 230 130 "Notification" "" @(
        "- id : int",
        "- titre : String",
        "- corps : String",
        "- type : String"
    ) @(
        "+ envoyerNotification() : Boolean"
    )

    &$DrawBox 1220 370 160 70 "Message" "" @(
        "- id : int",
        "- contenu : String"
    ) @()

    &$DrawBox 1150 540 240 150 "HistoriqueVersement" "" @(
        "- id : int",
        "- montant : Double",
        "- methode_paiement : String",
        "- statut : String"
    ) @(
        "+ enregistrerTrace() : void",
        "+ consulterHistorique() : void"
    )

    &$DrawBox 250 415 220 160 "Litige" "" @(
        "- id : int",
        "- motif : String",
        "- description : String",
        "- statut : String",
        "- notes_resolution : String"
    ) @(
        "+ ouvrir() : void",
        "+ cloturer() : void"
    )

    &$DrawBox 495 515 235 135 "Evaluation" "" @(
        "- id : int",
        "- note : int",
        "- commentaire : String",
        "- date_creation : Date"
    ) @(
        "+ calculerMoyenneGlobale() : Double"
    )

    &$DrawBox 270 700 265 255 "Mission" "" @(
        "- id : int",
        "- description_probleme : String",
        "- photos_probleme : String",
        "- niveau_urgence : String",
        "- solution_ia : String",
        "- latitude_client : Double",
        "- longitude_client : Double",
        "- date_demande : Date"
    ) @(
        "+ calculerDistance() : Double",
        "+ mettreAJourStatut() : void",
        "+ terminerMission() : void"
    )

    &$DrawBox 30 700 205 140 "Paiement" "" @(
        "- id : int",
        "- montant : Double",
        "- methode_paiement : String",
        "- statut : String",
        "- date_initiation : Date"
    ) @(
        "+ traiterTransaction() : Boolean"
    )

    &$DrawBox 150 970 225 160 "AbonnementTechnicien" "" @(
        "- id : int",
        "- type_abonnement : String",
        "- montant_paye : Double",
        "- date_debut : Date",
        "- date_fin : Date",
        "- statut : String"
    ) @(
        "+ verifierValidite() : Boolean"
    )

    &$DrawBox 700 810 190 110 "Categorie" "" @(
        "- id : int",
        "- nom : String",
        "- icone_url : String",
        "- description : String"
    ) @()

    &$DrawBox 480 970 220 130 "DemandeMission" "" @(
        "- id : int",
        "- statut : String",
        "- date_envoi : Date",
        "- date_expiration : Date"
    ) @(
        "+ verifierExpiration() : Boolean"
    )

    &$DrawBox 830 1030 200 110 "Devis" "" @(
        "- id : int",
        "- sous_total : Double",
        "- statut : String"
    ) @(
        "+ calculerTotal() : Double"
    )

    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Diagramme de classes exporte avec succes : $outputPath"
}

function Render-PackageDiagram {
    param([string]$outputPath, [float]$scale = 2.0)

    $width = [int](2250 * $scale)
    $height = [int](1080 * $scale)

    $bmp = New-Object System.Drawing.Bitmap ($width), ($height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)

    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $g.Clear([System.Drawing.Color]::White)

    # Couleurs du thème Paquetage UML
    $pkgFill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 253, 224))
    $pkgMainFill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 252, 199))
    $pkgBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(153, 115, 0)), ([float](1.6 * $scale))
    $pkgMainBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(153, 115, 0)), ([float](2.2 * $scale))
    
    $depPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(85, 85, 187)), ([float](1.5 * $scale))
    $depPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
    $depPen.DashPattern = [float[]]@(4.0, 3.0)

    $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(17, 17, 17))
    $stereoBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(51, 51, 136))
    $badgeBg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $badgeBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(187, 187, 221)), ([float](0.8 * $scale))

    $fontTitle = New-Object System.Drawing.Font ("Segoe UI", (11.5 * $scale), [System.Drawing.FontStyle]::Bold)
    $fontMainTitle = New-Object System.Drawing.Font ("Segoe UI", (13.5 * $scale), [System.Drawing.FontStyle]::Bold)
    $fontStereo = New-Object System.Drawing.Font ("Segoe UI", (9.5 * $scale), [System.Drawing.FontStyle]::Italic)

    $formatCenter = New-Object System.Drawing.StringFormat
    $formatCenter.Alignment = [System.Drawing.StringAlignment]::Center
    $formatCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

    # Tracé d'un paquetage UML
    $DrawPackage = {
        param($x, $y, $w, $h, $title, [bool]$isMain = $false)
        $rx = [float]($x * $scale)
        $ry = [float]($y * $scale)
        $rw = [float]($w * $scale)
        $rh = [float]($h * $scale)
        $tabW = [float]($(if ($isMain) { 65.0 * $scale } else { 48.0 * $scale }))
        $tabH = [float]($(if ($isMain) { 18.0 * $scale } else { 15.0 * $scale }))
        
        $pFillColor = if ($isMain) { [System.Drawing.Color]::FromArgb(255, 252, 199) } else { [System.Drawing.Color]::FromArgb(255, 253, 224) }
        $pBorderColor = [System.Drawing.Color]::FromArgb(153, 115, 0)
        $pBorderWidth = [float]($(if ($isMain) { 2.2 * $scale } else { 1.6 * $scale }))

        $currFill = New-Object System.Drawing.SolidBrush ($pFillColor)
        $currBorder = New-Object System.Drawing.Pen ($pBorderColor), ($pBorderWidth)
        $currFont = if ($isMain) { $fontMainTitle } else { $fontTitle }

        # Onglet
        $g.FillRectangle($currFill, $rx, $ry, $tabW, $tabH)
        $g.DrawRectangle($currBorder, $rx, $ry, $tabW, $tabH)

        # Corps
        $g.FillRectangle($currFill, $rx, ($ry + $tabH), $rw, ($rh - $tabH))
        $g.DrawRectangle($currBorder, $rx, ($ry + $tabH), $rw, ($rh - $tabH))

        # Masquer la ligne commune
        $g.FillRectangle($currFill, ($rx + 1.5*$scale), ($ry + $tabH - 1.0*$scale), ($tabW - 3.0*$scale), (3.0*$scale))

        # Titre
        $g.DrawString($title, $currFont, $textBrush, ($rx + $rw/2), ($ry + $tabH + ($rh - $tabH)/2), $formatCenter)

        $currFill.Dispose()
        $currBorder.Dispose()
    }

    # Tracé d'une dépendance <<access>> ou <<merge>>
    $DrawDep = {
        param([float[]]$pts, $stereo, [float[]]$stereoPos)
        for ($i = 0; $i -lt ($pts.Length - 2); $i += 2) {
            $x1 = [float]($pts[$i] * $scale)
            $y1 = [float]($pts[$i+1] * $scale)
            $x2 = [float]($pts[$i+2] * $scale)
            $y2 = [float]($pts[$i+3] * $scale)
            $g.DrawLine($depPen, $x1, $y1, $x2, $y2)
        }
        $lastIdx = $pts.Length - 2
        $pEndX = [float]($pts[$lastIdx] * $scale)
        $pEndY = [float]($pts[$lastIdx + 1] * $scale)
        $pPrevX = [float]($pts[$lastIdx - 2] * $scale)
        $pPrevY = [float]($pts[$lastIdx - 1] * $scale)
        $angle = [Math]::Atan2(($pEndY - $pPrevY), ($pEndX - $pPrevX))
        $aLen = 10.0 * $scale
        $arrowP1 = New-Object System.Drawing.PointF(($pEndX - $aLen * [Math]::Cos($angle - 0.5)), ($pEndY - $aLen * [Math]::Sin($angle - 0.5)))
        $arrowP2 = New-Object System.Drawing.PointF(($pEndX - $aLen * [Math]::Cos($angle + 0.5)), ($pEndY - $aLen * [Math]::Sin($angle + 0.5)))
        $solidPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(85, 85, 187)), ([float](1.8 * $scale))
        $g.DrawLine($solidPen, (New-Object System.Drawing.PointF($pEndX, $pEndY)), $arrowP1)
        $g.DrawLine($solidPen, (New-Object System.Drawing.PointF($pEndX, $pEndY)), $arrowP2)
        $solidPen.Dispose()

        if ($stereo -and $stereoPos) {
            $sx = [float]($stereoPos[0] * $scale)
            $sy = [float]($stereoPos[1] * $scale)
            $size = $g.MeasureString($stereo, $fontStereo)
            $sw = [float]($size.Width + 8.0 * $scale)
            $sh = [float](14.0 * $scale)
            $g.FillRectangle($badgeBg, ($sx - $sw/2), ($sy - $sh/2), $sw, $sh)
            $g.DrawRectangle($badgeBorder, ($sx - $sw/2), ($sy - $sh/2), $sw, $sh)
            $g.DrawString($stereo, $fontStereo, $stereoBrush, $sx, $sy, $formatCenter)
        }
    }

    # ================= 1. DÉPENDANCES =================
    &$DrawDep @(840, 165, 1070, 275) "<<access>>" @(955, 215)
    &$DrawDep @(1135, 145, 1135, 275) "<<access>>" @(1135, 210)
    &$DrawDep @(830, 295, 1045, 295) "<<access>>" @(940, 290)
    &$DrawDep @(890, 410, 1045, 370) "<<access>>" @(965, 390)
    &$DrawDep @(390, 460, 1045, 450) "<<access>>" @(700, 455)
    &$DrawDep @(1125, 600, 1125, 405) "<<access>>" @(1125, 490)
    &$DrawDep @(1205, 600, 1180, 405) "<<access>>" @(1190, 500)
    &$DrawDep @(1250, 545, 1225, 405) "<<access>>" @(1250, 470)
    &$DrawDep @(1450, 295, 1245, 310) "<<access>>" @(1350, 300)
    &$DrawDep @(1470, 450, 1245, 370) "<<access>>" @(1360, 410)
    &$DrawDep @(1460, 540, 1530, 485) "<<access>>" @(1490, 510)
    &$DrawDep @(1770, 390, 1245, 385) "<<access>>" @(1510, 387)

    # Merge vers GERER MISSION
    &$DrawDep @(295, 225, 295, 410) "<<merge>>" @(295, 320)
    &$DrawDep @(150, 345, 220, 430) "<<merge>>" @(175, 380)
    &$DrawDep @(160, 445, 220, 455) "<<merge>>" @(185, 448)
    &$DrawDep @(150, 595, 220, 500) "<<merge>>" @(180, 545)
    &$DrawDep @(220, 715, 305, 715, 305, 515) "<<merge>>" @(305, 665)

    # Merge vers GERER LES UTILISATEURS
    &$DrawDep @(550, 655, 770, 655) "<<merge>>" @(660, 650)
    &$DrawDep @(660, 785, 770, 785, 770, 705) "<<merge>>" @(715, 780)
    &$DrawDep @(820, 780, 820, 705) "<<merge>>" @(820, 745)
    &$DrawDep @(1000, 930, 1000, 705) "<<merge>>" @(1000, 820)
    &$DrawDep @(1120, 780, 970, 705) "<<merge>>" @(1050, 745)
    &$DrawDep @(1270, 690, 970, 690) "<<merge>>" @(1120, 685)

    # Merge vers GERER MISSION ATRIBUER
    &$DrawDep @(1775, 60, 1580, 60, 1580, 180) "<<merge>>" @(1580, 120)
    &$DrawDep @(2000, 130, 1680, 130, 1680, 180) "<<merge>>" @(1840, 125)
    &$DrawDep @(2020, 230, 1690, 230) "<<merge>>" @(1850, 225)
    &$DrawDep @(1880, 260, 1690, 260) "<<merge>>" @(1780, 255)
    &$DrawDep @(1550, 420, 1550, 305) "<<merge>>" @(1550, 360)

    # ================= 2. PAQUETAGES =================

    # Cœur
    &$DrawPackage 1045 275 200 130 "S'AUTHENTIFIER" $true

    # Haut
    &$DrawPackage 740 100 200 65 "CONSULTER NOTIFICATION"
    &$DrawPackage 1060 80 150 65 "SIGNALER LITIGER"

    # Gauche Haut & Milieu
    &$DrawPackage 550 260 280 75 "CONSULTER HISTORIQUE DE PAIEMENT"
    &$DrawPackage 740 380 150 65 "MODIFIER PROFIL"

    # Bloc GERER MISSION
    &$DrawPackage 220 410 170 105 "GERER MISSION" $true
    &$DrawPackage 230 160 135 65 "CREER MISSION"
    &$DrawPackage 0 310 150 65 "ANNULER MISSION"
    &$DrawPackage 20 410 140 65 "VALIDER DEVIS"
    &$DrawPackage 10 560 140 65 "REFUSER DEVIS"
    &$DrawPackage 100 680 120 65 "PAYER DEVIS"

    # Bloc GERER LES UTILISATEURS
    &$DrawPackage 770 600 200 105 "GERER LES UTILISATEURS" $true
    &$DrawPackage 380 625 170 65 "DESACTIVER COMPTE"
    &$DrawPackage 470 750 190 65 "ACCEPTER LE TECHNICIEN"
    &$DrawPackage 730 780 180 65 "REFUSER LE TECHNICIEN"
    &$DrawPackage 900 930 200 65 "VOIR PROFIL UTILISATEUR"
    &$DrawPackage 1030 780 185 65 "SUPPRIMER UTILISATEUR"
    &$DrawPackage 1270 660 145 65 "ACTIVER COMPTE"

    # Services
    &$DrawPackage 1070 600 110 65 "S'ABONNER"
    &$DrawPackage 1200 545 100 65 "CONTACTER"

    # Bloc GERER MISSION ATRIBUER
    &$DrawPackage 1450 180 240 125 "GERER MISSION ATRIBUER" $true
    &$DrawPackage 1700 0 150 60 "ACCEPTER MISSION"
    &$DrawPackage 2000 100 165 65 "REFUSER MISSION 2"
    &$DrawPackage 2020 200 150 65 "REFUSER MISSION"
    &$DrawPackage 1880 230 140 65 "ENVOYER DEVIS"
    &$DrawPackage 1770 360 150 65 "EXECUTER MISSION"

    # Litiges & Demande
    &$DrawPackage 1470 420 160 65 "GERER LES LITIGES"
    &$DrawPackage 1370 540 180 65 "SOUMMETRE DEMANDE"

    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Diagramme de paquetages exporte avec succes : $outputPath"
}

# Execution
Render-ClassDiagram "c:\Users\JORDAN\Desktop\techlink-app\diagramme_de_classes_hd.png" 2.0
Render-PackageDiagram "c:\Users\JORDAN\Desktop\techlink-app\diagramme_de_paquetages_hd.png" 2.0
