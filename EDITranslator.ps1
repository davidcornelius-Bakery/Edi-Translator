param (
    [string]$Customer = "ICurate",
    [String]$Mode = "DEMO"
)
#Cybake order processing.
#XML files
<#
<order>
<header>
<testStatus>N</testStatus>
<supplierIdentifier>Morris Quality Bakers</supplierIdentifier>
<purchaseOrderReference>FS2898-050516A</purchaseOrderReference>
<internalOrderReference>7d33bb59-3c4d-4dff-90a7-a99f1f9f6ca9</internalOrderReference>
<purchaseOrderDate>20160505</purchaseOrderDate>
<requestedDeliveryDate>20160510</requestedDeliveryDate>
<deliverySlotStartTime />
<deliverySlotEndTime />
<deliveryLocationContact />
<deliveryAddress1>Newton Westpark Primary School</deliveryAddress1>
<deliveryAddress2>Tennyson Avenue</deliveryAddress2>
<deliveryAddress3>Leigh</deliveryAddress3>
<deliveryAddress4 />
<deliveryAddress5 />
<deliveryAddressPostCode>WN7 5JY</deliveryAddressPostCode>
<numberOfOrderItems>2</numberOfOrderItems>
<orderTotalValue>3.86000</orderTotalValue>
<locationIdentifier>FS2898</locationIdentifier>
<locationAccountCode>1367</locationAccountCode>
<globalLocationNumber>5060397700148</globalLocationNumber>
<orderingOrganisationName>Food Service Options</orderingOrganisationName>
<supplierCode />
</header>
<orderItems>
<item>
    <itemName>Good Fresh Brown Wholemeal Medium 800g</itemName>
    <itemCode>6007</itemCode>
    <itemNote />
    <itemQuantityPerUnit>Pack</itemQuantityPerUnit>
    <itemQuantity>2.000</itemQuantity>
    <itemUnitPrice>1.01</itemUnitPrice>
    <itemLineTotalPrice>2.02000</itemLineTotalPrice>
</item>
<item>
    <itemName>Medium White 800g</itemName>
    <itemCode>6001</itemCode>
    <itemNote />
    <itemQuantityPerUnit>Pack</itemQuantityPerUnit>
    <itemQuantity>2.000</itemQuantity>
    <itemUnitPrice>0.92</itemUnitPrice>
    <itemLineTotalPrice>1.84000</itemLineTotalPrice>
</item>
</orderItems>
</order>
#>
Function Cybake {
    $files = Get-ChildItem $filepath
    $cedifile = @() 
    foreach ($file in $Files) {
        [XML]$OrderXML = Get-Content $file
        $cdeliverydate = $orderxml.order.header.requestedDeliveryDate
        $cdeliverydate = $cdeliverydate.substring(2, 6)
        $cStoreANA = ''
        $cstorelocation = $orderxml.order.header.locationAccountCode
        $corderID = $orderxml.order.header.purchaseOrderReference
        $orderlines = $orderxml.order.orderitems.item
        
        foreach ($line in $orderlines) {
            $cproductcode = $line.itemCode
            $corderquantity = $line.itemQuantity
            $index = $cOrderquantity.IndexOf('.')
            if ($index -ne 0) {
                $cOrderquantity = $cOrderquantity.Substring(0, $index)
            }
            $cproductdescription = $line.itemName
            $cproductEAN = ''
            $cedifile += [pscustomobject]@{DeliveryDate = $cdeliverydate; StoreANA = $cstoreana; StoreLocation = $cstorelocation; ProductEAN = $cproductEAN; Productdescription = $cproductDescription; Orderquantity = $cOrderquantity; OrderNumber = $cOrderID; ProductCode = $cProductCode }
        }
        if ($mode -ne 'DEMO') { remove-item $file }
    }
    return $cedifile
}
<#
ICurate edi orders
GS1 XML format
#>
Function GS1XML {
    $files = Get-ChildItem $filepath
    $cedifile = @() 
    foreach ($file in $Files) {
        [XML]$OrderXML = Get-Content $file

        $cdeliverydate = $orderxml.orderMessage.order.orderLogisticalInformation.orderLogisticalDateInformation.requestedDeliveryDateTime.date

        $cdeliverydate = $cdeliverydate.substring(2, 2) + $cdeliverydate.substring(5, 2) + $cdeliverydate.substring(8, 2)
        $cStoreANA = $orderxml.orderMessage.order.orderLogisticalInformation.shipTo.gln
        $cstorelocation = ''
        $corderID = $orderxml.orderMessage.order.orderIdentification.entityIdentification
        $orderlines = $orderxml.orderMessage.order.orderLineItem
        
        
        foreach ($line in $orderlines) {
            $cproductcode = ''
            $xorderquantity = $line.requestedQuantity
            $corderquantity = $xorderquantity.Innertext

            $index = $cOrderquantity.IndexOf('.')
            if ($index -ne -1) {
                $cOrderquantity = $cOrderquantity.Substring(0, $index)
            }
            $cproductdescription = ''
            $cproductEAN = $line.transactionalTradeItem.gtin
            $cedifile += [pscustomobject]@{DeliveryDate = $cdeliverydate; StoreANA = $cstoreana; StoreLocation = $cstorelocation; ProductEAN = $cproductEAN; Productdescription = $cproductDescription; Orderquantity = $cOrderquantity; OrderNumber = $cOrderID; ProductCode = $cProductCode }
        }
        if ($mode -ne 'DEMO') { remove-item $file }
    }
    return $cedifile
}

#Icurate
#CSV FILE format
#HEAD,Test Site,Heath Way,WS11 7AD,TESTCUST,Test Supplier,Edison Road,HP19 8XU,TESTSUPP,ORD2413600001,150524,170524,,,,,,,
#LINE,BK302-0001-PK4,Bread Baton White Pack X 4,Z,,100.0000,150.00,,,,
#LINE,BK302-0002-PK4,Bread Baton Wholemeal Pack X 4,Z,,50.0000,75.00,,,,
#TAIL,ORD2413600001,225.00,2
Function ICurate {
    #Translate Icurate csv to standard EDI orders
    $files = Get-ChildItem $filepath
    $iedifile = @()

    $sana = $settings.bakerycomputing.orders.storeana
    
    #step through files in folder
    foreach ($file in $Files) {
        $data = Get-Content -Path $file
        #step though the csv
        foreach ($row in $data) {
            $rdata = $row -split ","
            if ($rdata[0] -eq 'HEAD') {
                #delivery date
                $ddate = $rdata[11]
                $ideliverydate = $ddate.Substring(4, 2) + $ddate.Substring(2, 2) + $ddate.Substring(0, 2)
                #storeana
                $istoreana = $sana
                #Store location
                $istorelocation = $rdata[4]
                #Order ID
                $iOrderID = $rdata[9]
            }
            if ($rdata[0] -eq 'LINE') {
                #Product EAN
                $iproductEAN = ""
                #Order Quantity
                $iOrderquantity = $rdata[5]
                $index = $iOrderquantity.IndexOf('.')
                if ($index -ne -1) {
                    $iOrderquantity = $iOrderquantity.Substring(0,$index)
                }
                #Product Description
                $iproductDescription = $rdata[2]
                #ProductCode
                $iProductCode = $rdata[1]
                #Add line to file
                $iedifile += [pscustomobject]@{DeliveryDate = $ideliverydate; StoreANA = $istoreana; StoreLocation = $istorelocation; ProductEAN = $iproductEAN; Productdescription = $iproductDescription; Orderquantity = $iOrderquantity; OrderNumber = $iOrderID; ProductCode = $iProductCode }
            }
        }
        if ($mode -ne 'DEMO') { remove-item $file }
    }
    return $iedifile
}

#Enterprise EDI order 
#This is a H,D format
<#
H,ARA3348,N,334810194,06/01/22,10/01/22,,,James Houlden,St Thomas More Catholic High School,Danebank Avenue,,Crewe,,CW2 8AE,2,12,
D,6295,North Staffs Oatcakes X 6 ,6,6,,
D,6416,6 Kingsmill Crumpets,6,6,,
#>
Function Enterprise {
    $files = Get-ChildItem $filepath
    $eedifile = @()
    #step through files in folder
    foreach ($file in $Files) {
        $data = Get-Content -Path $file
        #step though the file
        foreach ($row in $data) {
            $elinetype = $row.Substring(0, 1)
            if ( $elinetype -eq 'H') {
                $eheader = $data.split(',')
                #Store location
                $eStorelocation = $eheader[1]
                #lookup text to remove from the store location
                $estorelookups = $settings.bakerycomputing.orders.storeids.id
                foreach ($id in $estorelookups) {
                    $eStorelocation = $eStorelocation.Replace($id.value, '')
                }
                #Delivery date
                $edeliverydate = $eheader[5]
                $edeliverydate = $edeliverydate.substring(6, 2) + $edeliverydate.substring(3, 2) + $edeliverydate.substring(0, 2)  

                #StoreANA
                $estoreana = $settings.bakerycomputing.orders.storeana          
                if ($null -eq $estoreana ) { $estoreana = "" }

                #Ordernumber
                $eorderID = $eheader[3] 
            }
            else {
                $eorderline = $row.split(',')
                
                #Product code
                $eproductcode = $eorderline[1]

                #Product EAN
                $eproductEAN = ''

                #Product Description
                $eProductDescription = $eorderline[2]

                #Order Quantity
                $eOrderquantity = $eorderline[3]

                #Add line to file
                $eedifile += [pscustomobject]@{DeliveryDate = $edeliverydate; StoreANA = $estoreana; StoreLocation = $estorelocation; ProductEAN = $eproductEAN; Productdescription = $eproductDescription; Orderquantity = $eOrderquantity; OrderNumber = $eOrderID; ProductCode = $eProductCode }                
            }     
        }
        if ($mode -ne 'DEMO') { remove-item $file }
    }
    return $eedifile
}


#Start of Main process

$Customer

$wdir = $PSScriptRoot + '\'
$xmlfilename = $wdir + $customer + '.xml'
#Load XML file and get values
$testxml = test-Path -Path $xmlfilename -PathType Leaf
if ($Testxml -eq $true) {
    [XML]$settings = Get-Content $xmlfilename

    $filepath = $settings.bakerycomputing.orders.filepath
    $savepath = $settings.bakerycomputing.orders.savepath
    $filecount = $settings.bakerycomputing.orders.count
    $savefilename = $settings.bakerycomputing.order.filename
    $saveext = $settings.bakerycomputing.order.ext        
    if ($null -eq $savefilename -or $savefilename -eq '') { 
        $savefilename = 'Order'
    }

    if ($null -eq $saveext -or $saveext -eq '') { 
        $saveext = 'ord'
    }

    if ($Customer -ne "Blank") {
        $customerprocess = switch ($customer) {
            "ICurate" { Icurate }
            "Cybake" { Cybake }
            "Enterprise" { Enterprise }
            Default {}
        }
        # $customerprocess
        $edioutput = @()
        if ($customerprocess.Count -ne 0) {
            foreach ($row in $customerprocess) {
                [string]$edi = 'ATN'
                $edi = $edi + $row.DeliveryDate
                #Storeana
                [string]$storeana = $row.storeana
                if ($storeana.Length -lt 13) {
                    do {
                        $storeana = $storeana + ' '
                    } while (
                        <# Condition that stops the loop if it returns false #>
                        $storeana.Length -ne 13
                    )
                }   
                $edi = $edi + $storeana

                #Store location
                [string]$storelocation = $row.StoreLocation

                if ($storelocation.Length -ge 7) {
                    $storelocation = $storelocation.substring(0, 7)
                }
                else {
                    do {
                        $storelocation = $storelocation + ' '
                    } while (
                        <# Condition that stops the loop if it returns false #>
                        $storelocation.Length -ne 7
                    )
                }
                $edi = $edi + $storelocation
                $edi = $edi + "01"

                #Product EAN
                [string]$productEAN = $row.productEAN
                if ($productEAN.Length -lt 13) {
                    do {
                        $productEAN = $productEAN + ' '
                    } while (
                        <# Condition that stops the loop if it returns false #>
                        $productEAN.Length -ne 13
                    )
                }
                $edi = $edi + $productEAN

                #Order Quantity
                [string]$Orderquantity = $row.orderquantity
                do {
                    $Orderquantity = '0' + $Orderquantity
                } while (
                    <# Condition that stops the loop if it returns false #>
                    $Orderquantity.Length -ne 15
                )
                $edi = $edi + $Orderquantity

                #Product Description
                [string]$productDescription = $row.productdescription
                if ($productDescription.Length -ge 30) {
                    $productDescription = $productDescription.substring(0, 30)
                }
                else {
                    <# Action when all if and elseif conditions are false #>
                    do {
                        $productDescription = $productDescription + ' '
                    } while (
                        <# Condition that stops the loop if it returns false #>
                        $productDescription.Length -ne 30
                    )
                }
                $edi = $edi + $productDescription

                #Order ID
                [string]$OrderID = $row.ordernumber
                do {
                    $OrderID = $OrderID + ' '
                } while (
                    <# Condition that stops the loop if it returns false #>
                    $OrderID.Length -ne 17
                )
                $edi = $edi + $OrderID

                #ProductCode
                [string]$ProductCode = $row.productcode
                do {
                    $ProductCode = $ProductCode + ' '
                } while (
                    <# Condition that stops the loop if it returns false #>
                    $ProductCode.Length -ne 15
                )
                $edi = $edi + $ProductCode

                #Add line to file
                $edioutput += $edi
            }
            $logfilename = $savepath + $savefilename + $filecount + "." + $saveext
            $edioutput | Out-File  $logfilename
            [int]$icount = $filecount
            $icount++
            if ($icount -eq 999) { $icount = 1 }
            $settings.bakerycomputing.orders.count = $icount.tostring()
            $settings.Save($xmlfilename)
            $edioutput
            $logfilename
            if ($mode -eq 'DEMO') { Read-Host -Prompt "Press Enter to continue" }
        }
    }
}

