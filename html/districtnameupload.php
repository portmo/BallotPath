<?php include('../html/secr/login.php');
require($_SERVER['DOCUMENT_ROOT'] . "/inc/BPWebConfig.php"); ?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Upload Database Name Changes</title>
    <link href="css/custom.css" rel="stylesheet"> 

<!-- Latest compiled and minified CSS -->
<link rel="stylesheet" href="http://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css">

<!-- Optional theme -->
<link rel="stylesheet" href="http://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap-theme.min.css">

<!-- Remain consistent with home page theme -->    
<link href="css/landing-page.css" rel="stylesheet">
    
	<script src="http://code.jquery.com/jquery-latest.min.js"></script>
	<script src="js/officeCard.js"></script>
<!-- Latest compiled and minified JavaScript -->
<script src="//netdna.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js"></script>
</head>

<body class="bgprimary">
    <nav class="navbar navbar-inverse navbar-fixed-top" role="navigation">
        <div class="container">
            <div class="navbar-header">
                <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-ex1-collapse">
                    <span class="sr-only">Toggle navigation</span>
                    <span class="icon-bar"></span>
                    <span class="icon-bar"></span>
                    <span class="icon-bar"></span>
                </button>
                <a class="navbar-brand" href="/">Ballot Path</a>
            </div>

            <!-- Collect the nav links, forms, and other content for toggling -->
            <div class="collapse navbar-collapse navbar-right navbar-ex1-collapse">
                <ul class="nav navbar-nav">
                    <li><a href="#about">About</a>
                    </li>
                    <li><a href="#services">Partners</a>
                    </li>
                    <li><a href="#contact">Contact Us</a>
                    </li>
                    <li><a href="#contact">Help</a>
                    </li>
                </ul>
            </div>
            <!-- /.navbar-collapse -->
        </div>
        <!-- /.container -->
    </nav>
	


<div class="intro-header">
	<div class="container-fluid col-md-10 col-md-offset-1">
		<div class="panel panel-primary ">
			<div class="panel-heading">
				<h4 class="panel-title">
					Database name change request
				</h4>
			</div>
			<div class="inpAdmin panel-body">

<?php

function uploadProcess($extension) {
  if($_FILES["$extension"]["error"] > 0) {
    echo "Error uploading .$extension: " . printUploadError($_FILES["$extension"]["error"]) . "<br>";
  return 0;
  } else {
    if(substr($_FILES["$extension"]["name"], -3) == "$extension") {
      echo "File ". $_FILES["$extension"]["name"] . " upload successful!<br>";
      move_uploaded_file($_FILES["$extension"]["tmp_name"], "/tmp/" . $_FILES["$extension"]["name"]);
      return 1;
    } else {
      echo "Incorrect file type uploaded for .$extension file, please return to the previous page and submit the correct file type.<br>";
      return 0;
    }
  }
}

function printUploadError($errcode) {
  $output;
  switch($errcode) {
    case 0:
      $output = "There is no error, the file uploaded with success";
      break;
    case 1:
      $output = "The uploaded file exceeds the upload_max_filesize directive in php.ini";
      break;
    case 2:
      $output = "The uploaded file exceeds the MAX_FILE_SIZE directive that was specified in the HTML form";
      break;
    case 3:
      $output = "The uploaded file was only partially uploaded";
      break;
    case 4:
      $output = "No file was uploaded";
      break;
    case 6:
      $output = "Missing a temporary folder";
      break;
    case 7:
      $output = "Failed to write file to disk";
      break;
    case 8:
      $output = "A PHP extensioned the file upload";
      break;
  }
  return $output;
}

function cleanup() {
  $cleartmp = shell_exec('rm /tmp/' . $_FILES["csv"]["name"]);
  echo $cleartmp;
}

//array for storing upload status
$upload = array(
  "csv" => 0
);

//call function to process each upload
$upload["csv"] = uploadProcess("csv");

//perform action and remove temp files in directory
if(($upload["csv"] == 0)) {

  //display error message
  echo "Error during CSV file upload!  CSV database insertion halted.";
  cleanup();
} else {
  //open file for reading
  $file = fopen("/tmp/" . $_FILES["csv"]["name"], "r");
  if ($file) {
    echo "File opened successfully.<br>";
    //create db connection
    $dbconn = pg_connect("host=" . $dbhost . " port=" . $dbport . " dbname=" . $dbname . " user=" . $dbuser . " password=" . $dbpassword)
	or die ("Could not connect to server\n");
    while (($line = fgets($file)) !== false) {
      //echo $line;
      $lineary = explode(";", $line);
      $qryupdate = "UPDATE district SET name = '" . pg_escape_string($lineary[1]) . "' WHERE name = '" . pg_escape_string($lineary[0]) . "';";
      $rs = pg_query($dbconn, $qryupdate);
      if ($rs == FALSE) {
        echo '<p class"hangingindent">' . pg_last_error($dbconn);
      } else {
        $rows = pg_affected_rows($rs);
        if ( $rows == 0 ) {
          echo "No matching record found for '" . $lineary[0] . "'.<br>";
        } else {
          echo "<p>District name '" . $lineary[0] . "' changed to '" . $lineary[1] . "'.<br/>" . $rows . " row(s) changed.";
        }
      }
    }
    pg_close($dbconn);
  } else {
    echo "There was an issue opening the file.";
  }
  fclose($file);
  cleanup();
}

?>

			</div>
		</div>
	</div>
</div>
	
	
</body>
</html>
