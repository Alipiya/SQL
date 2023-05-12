USE lesson_4;

START TRANSACTION;

INSERT INTO users (firstname, lastname, email)
VALUES ('Дмитрий', 'Дмитриев', 'dima@mail.ru');
	
SET @last_user_id = last_insert_id();
	
INSERT INTO profiles (user_id, hometown, birthday, photo_id)
VALUES (@last_user_id, 'Moscow', '1999-10-10', NULL);

COMMIT;

DROP PROCEDURE IF EXISTS sp_user_add;
DELIMITER //
CREATE PROCEDURE sp_user_add(
firstname varchar(100), lastname varchar(100), email varchar(100), 
phone varchar(100), hometown varchar(50), photo_id INT, birthday DATE,
OUT  tran_result varchar(100))
BEGIN
	
	DECLARE `_rollback` BIT DEFAULT 0;
	DECLARE code varchar(100);
	DECLARE error_string varchar(100); 

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
	BEGIN
 		SET `_rollback` = 1;
 		GET stacked DIAGNOSTICS CONDITION 1
			code = RETURNED_SQLSTATE, error_string = MESSAGE_TEXT;
	END;

	START TRANSACTION;
	 INSERT INTO users (firstname, lastname, email)
	 VALUES (firstname, lastname, email);

	 INSERT INTO profiles (user_id, hometown, birthday, photo_id)
	 VALUES (last_insert_id(), hometown, birthday, photo_id);
	
	IF `_rollback` THEN
		SET tran_result = concat('УПС. Ошибка: ', code, ' Текст ошибки: ', error_string);
		ROLLBACK;
	ELSE
		SET tran_result = 'O K';
		COMMIT;
	END IF;
END//
DELIMITER ;


CALL sp_user_add('New', 'User', 'new_user1@mail.com', 9110001122, 'Moscow', -1, '1998-01-01', @tran_result); 
SELECT @tran_result;

UPDATE profiles
SET hometown = 'Adriannaport'
WHERE birthday < '1990-01-01';

DROP PROCEDURE IF EXISTS sp_friendship_offers;
DELIMITER //
CREATE PROCEDURE sp_friendship_offers(for_user_id BIGINT)
BEGIN

WITH friends AS (
	SELECT initiator_user_id AS id
    FROM friend_requests
    WHERE status = 'approved' AND target_user_id = for_user_id 
    UNION
    SELECT target_user_id 
    FROM friend_requests
    WHERE status = 'approved' AND initiator_user_id = for_user_id 
)

	SELECT p2.user_id
	FROM profiles p1
	JOIN profiles p2 ON p1.hometown = p2.hometown 
	WHERE p1.user_id = for_user_id AND p2.user_id <> for_user_id
    UNION 

	SELECT uc2.user_id FROM users_communities uc1
	JOIN users_communities uc2 ON uc1.community_id = uc2.community_id 
	WHERE uc1.user_id = for_user_id AND uc2.user_id <> for_user_id

    UNION
	SELECT fr.initiator_user_id
    	FROM friends f
        JOIN friend_requests fr ON fr.target_user_id = f.id
	WHERE fr.initiator_user_id != for_user_id  AND fr.status = 'approved'
    UNION
    	SELECT fr.target_user_id
    	FROM  friends f
        JOIN  friend_requests fr ON fr.initiator_user_id = f.id 
	WHERE fr.target_user_id != for_user_id  AND status = 'approved'
	ORDER BY rand()
	LIMIT 5;
	
END//

DELIMITER ;

CALL sp_friendship_offers(1);

DROP FUNCTION IF EXISTS friendship_direction;
DELIMITER //
CREATE FUNCTION friendship_direction(check_user_id BIGINT)
RETURNS FLOAT READS SQL DATA 
BEGIN
	DECLARE requests_to_user INT; 
	DECLARE requests_from_user INT; 

	SET requests_to_user = (
		SELECT count(*) 
		FROM friend_requests
		WHERE target_user_id = check_user_id 
		);

	SELECT count(*)
	INTO  requests_from_user
	FROM friend_requests
	WHERE initiator_user_id = check_user_id; 
	
	RETURN requests_to_user / requests_from_user;
END//
DELIMITER ;


SELECT friendship_direction(1);
SELECT truncate(friendship_direction(1), 2)*100 AS `user popularity`;