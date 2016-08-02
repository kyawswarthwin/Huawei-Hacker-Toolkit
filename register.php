<?php
include 'database.php';
if (isset($_POST['serial_number']) and isset($_POST['hardware_id'])) {
	$serial_number = mysqli_real_escape_string($link, $_POST['serial_number']);
	$hardware_id = mysqli_real_escape_string($link, $_POST['hardware_id']);
	$query = "INSERT INTO `$database`.`licenses` (`id`, `serial_number`, `hardware_id`) VALUES (NULL, '$serial_number', '$hardware_id')";
	if (mysqli_query($link, $query)) {
		echo "Registration Has Been Successful.";
	} else {
		$query = "SELECT * FROM `licenses` WHERE `serial_number` = '$serial_number'";
		$result = mysqli_query($link, $query);
		if ($result) {
			$row = mysqli_fetch_row($result);
			if ($row[2] == $hardware_id) {
				echo "Registration Has Been Successful.";
			} else {
				echo "Error: Serial Number Has Already Been Used.";
			}
		} else {
			echo "Error: Unable To Register.";
		}
	}
} else {
	echo "Access Denied!";
}
?>
