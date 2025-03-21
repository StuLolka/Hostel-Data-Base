-- Создание таблиц
-- CREATE TABLE rooms (
--     room_id INT AUTO_INCREMENT PRIMARY KEY,
--     number SMALLINT UNSIGNED NOT NULL UNIQUE,
--     double_bed TINYINT UNSIGNED NOT NULL,
--     single_bed TINYINT UNSIGNED NOT NULL,
--     class ENUM('Стандарт', 'Полулюкс', 'Люкс') NOT NULL,
--     area DECIMAL(5, 2) UNSIGNED NOT NULL,
--     price_per_night DECIMAL(10, 2) UNSIGNED NOT NULL
-- );

-- CREATE TABLE guests (
--     guest_id INT AUTO_INCREMENT PRIMARY KEY,
--     first_name VARCHAR(100) NOT NULL,
--     last_name VARCHAR(100) NOT NULL,
--     patronymic VARCHAR(100), 
--     passport VARCHAR(20) UNIQUE NOT NULL,
--     email VARCHAR(100) UNIQUE NOT NULL,
--     phone_number VARCHAR(20) UNIQUE NOT NULL
-- );

-- CREATE TABLE reservations (
--     reservation_id INT AUTO_INCREMENT PRIMARY KEY,
--     guest_id INT NOT NULL,
--     room_id INT NOT NULL,
--     check_in_date DATE NOT NULL,
--     check_out_date DATE NOT NULL,
--     total_room_price DECIMAL(10, 2) UNSIGNED NOT NULL DEFAULT 0,
--     total_service_price DECIMAL(10, 2) UNSIGNED NOT NULL DEFAULT 0,
--     amount_paid DECIMAL(10, 2) UNSIGNED NOT NULL DEFAULT 0,
--     amount_remaining DECIMAL(10, 2) UNSIGNED NOT NULL DEFAULT 0,
--     FOREIGN KEY (guest_id) REFERENCES guests(guest_id) ON DELETE CASCADE,
--     FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE
-- );

-- CREATE TABLE services (
--     service_id INT AUTO_INCREMENT PRIMARY KEY,
--     service_name VARCHAR(100) NOT NULL UNIQUE,
--     description TEXT,
--     is_price_fixed BOOLEAN NOT NULL DEFAULT TRUE,
--     price DECIMAL(10, 2) UNSIGNED NOT NULL
-- );

-- CREATE TABLE reservation_services (
--     reservation_service_id INT AUTO_INCREMENT PRIMARY KEY,
--     reservation_id INT NOT NULL,
--     service_id INT NOT NULL,
--     quantity TINYINT UNSIGNED NOT NULL DEFAULT 1,
--     total_price DECIMAL(10, 2) UNSIGNED NOT NULL DEFAULT 0,
--     FOREIGN KEY (reservation_id) REFERENCES reservations(reservation_id) ON DELETE CASCADE,
--     FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE CASCADE
-- );

-- CREATE TABLE payments (
--     payment_id INT AUTO_INCREMENT PRIMARY KEY,
--     reservation_id INT NOT NULL,
--     payment_date DATE NOT NULL,
--     payment_method ENUM('Наличные', 'Карта', 'Онлайн') NOT NULL,
--     total DECIMAL(10, 2) UNSIGNED NOT NULL DEFAULT 0,
--     FOREIGN KEY (reservation_id) REFERENCES reservations(reservation_id) ON DELETE CASCADE
-- );

-- Триггеры
-- Триггер, считающий стоимость бронирования комнаты 
-- DELIMITER $$
-- CREATE TRIGGER calculate_total_room_price
-- BEFORE INSERT ON reservations
-- FOR EACH ROW
-- BEGIN
--     DECLARE price DECIMAL(10, 2);

--     IF NEW.check_in_date < CURDATE() THEN
--         SIGNAL SQLSTATE '45000' 
--         SET MESSAGE_TEXT = 'Дата въезда не может быть раньше текущей даты.';
--     END IF;

--     IF NEW.check_out_date <= NEW.check_in_date THEN
--         SET @errorMsg = CONCAT('Дата выезда: ', 
--                                 DATE_FORMAT(NEW.check_out_date, '%d-%m-%Y'),
--                                 ' должна быть хотя бы на один день позже даты въезда: ', 
--                                 DATE_FORMAT(NEW.check_in_date, '%d-%m-%Y'));
--         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
--     END IF;
--     
--     SELECT price_per_night INTO price
--     FROM rooms
--     WHERE room_id = NEW.room_id;
--     
--     SET NEW.total_room_price = price * DATEDIFF(NEW.check_out_date, NEW.check_in_date);
-- 	SET NEW.amount_remaining = NEW.total_room_price;
-- END$$
-- DELIMITER ;

-- Триггер, обновляющий стоимость бронирования, если изменились даты или комната
-- DELIMITER $$
-- CREATE TRIGGER update_total_price
-- BEFORE UPDATE ON reservations
-- FOR EACH ROW
-- BEGIN
--     DECLARE price DECIMAL(10, 2);
--     DECLARE old_duration INT;
--     DECLARE new_duration INT;

--     IF NEW.check_in_date < CURDATE() THEN
--         SIGNAL SQLSTATE '45000' 
--         SET MESSAGE_TEXT = 'Дата въезда не может быть раньше текущей даты.';
--     END IF;

--     IF NEW.check_out_date <= NEW.check_in_date THEN
--         SET @errorMsg = CONCAT('Дата выезда: ', 
--                                 DATE_FORMAT(NEW.check_out_date, '%d-%m-%Y'),
--                                 ' должна быть хотя бы на один день позже даты въезда: ', 
--                                 DATE_FORMAT(NEW.check_in_date, '%d-%m-%Y'));
--         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
--     END IF;

--     SET old_duration = DATEDIFF(OLD.check_out_date, OLD.check_in_date);
--     SET new_duration = DATEDIFF(NEW.check_out_date, NEW.check_in_date);

--     IF OLD.check_in_date <= CURDATE() AND CURDATE() <= OLD.check_out_date THEN
--         IF NEW.check_in_date <> OLD.check_in_date THEN
--             SET @errorMsg = CONCAT('Дата въезда: ', 
--                                     DATE_FORMAT(OLD.check_in_date, '%d-%m-%Y'),
--                                     ' не может быть изменена: ', 
--                                     DATE_FORMAT(NEW.check_in_date, '%d-%m-%Y'),
--                                     ', так как бронирование уже активно. ID: ',
--                                     NEW.reservation_id);
--             SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
--         END IF;

--         IF NEW.check_out_date < OLD.check_out_date THEN
--             SET @errorMsg = CONCAT('Дата выезда: ', 
--                                     DATE_FORMAT(OLD.check_out_date, '%d-%m-%Y'),
--                                     ' не может быть уменьшена: ', 
--                                     DATE_FORMAT(NEW.check_out_date, '%d-%m-%Y'),
--                                     ', так как бронирование уже активно. ID: ',
--                                     NEW.reservation_id);
--             SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
--         END IF;
-- 	END IF; 

--     SELECT price_per_night INTO price
--     FROM rooms
--     WHERE room_id = NEW.room_id;

-- 	IF price * new_duration < OLD.total_room_price THEN
-- 	        SET @errorMsg = CONCAT('Новая стоимость: ', 
--                                     price * new_duration,
--                                     ' не может быть меньше старой: ', 
--                                     OLD.total_room_price,
--                                     ', так как возврат средств не предусмотрен. ID: ',
--                                     NEW.reservation_id);
--             SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
-- 	END IF;

--     SET NEW.total_room_price = price * new_duration;
--     SET NEW.amount_remaining = NEW.total_room_price + NEW.total_service_price - NEW.amount_paid;
-- END$$
-- DELIMITER ;

-- Триггер, проверяющий, что номер не занят на определенную дату
-- DELIMITER $$
-- CREATE TRIGGER check_room_availability
-- BEFORE INSERT ON reservations
-- FOR EACH ROW
-- BEGIN

-- 	DECLARE conflict_reservation_id INT;
--     DECLARE conflict_room_id INT;
--     DECLARE conflict_check_in DATE;
--     DECLARE conflict_check_out DATE;

--     SELECT reservation_id, room_id, check_in_date, check_out_date
--     INTO conflict_reservation_id, conflict_room_id, conflict_check_in, conflict_check_out
--     FROM reservations
--     WHERE room_id = NEW.room_id
--       AND (
--           (NEW.check_in_date < check_out_date) AND
--           (NEW.check_out_date > check_in_date)    
--       )
--     LIMIT 1;

--     IF conflict_room_id IS NOT NULL THEN
--         SET @errorMsg = CONCAT(
--             'Комната ', conflict_room_id, 
--             ' уже забронирована с ', DATE_FORMAT(conflict_check_in, '%d-%m-%Y'), 
--             ' по ', DATE_FORMAT(conflict_check_out, '%d-%m-%Y'), ', id: ', conflict_reservation_id,
--             '. Невозможно забронировать с ', DATE_FORMAT(NEW.check_in_date, '%d-%m-%Y'),
--             ' по ', DATE_FORMAT(NEW.check_out_date, '%d-%m-%Y'));

--         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
--     END IF;
-- END$$
-- DELIMITER ;

-- DELIMITER $$
-- CREATE TRIGGER check_room_availability_on_update
-- BEFORE UPDATE ON reservations
-- FOR EACH ROW
-- BEGIN
--     DECLARE conflict_reservation_id INT;
--     DECLARE conflict_room_id INT;
--     DECLARE conflict_check_in DATE;
--     DECLARE conflict_check_out DATE;

--     SELECT reservation_id, room_id, check_in_date, check_out_date
--     INTO conflict_reservation_id, conflict_room_id, conflict_check_in, conflict_check_out
--     FROM reservations
--     WHERE room_id = NEW.room_id AND reservation_id <> NEW.reservation_id
--       AND (
--           (NEW.check_in_date < check_out_date) AND
--           (NEW.check_out_date > check_in_date)     
--       )
--     LIMIT 1;

--     IF conflict_room_id IS NOT NULL THEN
--         SET @errorMsg = CONCAT(
--             'Комната ', conflict_room_id, 
--             ' уже забронирована с ', DATE_FORMAT(conflict_check_in, '%d-%m-%Y'), 
--             ' по ', DATE_FORMAT(conflict_check_out, '%d-%m-%Y'),
--             ', id: ', conflict_reservation_id,
--             '. Невозможно оформить бронирование ', NEW.reservation_id, '.');
--         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
--     END IF;
-- END$$
-- DELIMITER ;

-- Триггер, считающий стоимость услуг
-- DELIMITER $$
-- CREATE TRIGGER calculate_service_price
-- BEFORE INSERT ON reservation_services
-- FOR EACH ROW
-- BEGIN
--     DECLARE service_price DECIMAL(10, 2);
--     DECLARE is_service_price_fixed BOOLEAN;
--     DECLARE existing_fixed_service INT;

--     SELECT price, is_price_fixed INTO service_price, is_service_price_fixed
--     FROM services
--     WHERE service_id = NEW.service_id;

--     IF NOT is_service_price_fixed THEN
--         SET NEW.total_price = service_price * NEW.quantity;
--     ELSE
--         SET NEW.total_price = service_price;
--     END IF;

--     IF is_service_price_fixed THEN
--         SELECT COUNT(*) INTO existing_fixed_service
--         FROM reservation_services
--         WHERE reservation_id = NEW.reservation_id AND service_id = NEW.service_id;
--         IF existing_fixed_service > 0 THEN
--             SET @errorMsg = CONCAT('Услуга ', NEW.service_id, ' уже была добавлена в эту (', NEW.reservation_id, ') бронь.');
--             SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
--         END IF;
--     END IF;

--     UPDATE reservations
--     SET total_service_price = total_service_price + NEW.total_price,
--         amount_remaining = amount_remaining + NEW.total_price
--     WHERE reservation_id = NEW.reservation_id;
-- END$$
-- DELIMITER ;

-- Запрет на обновление заказанных услуг
-- DELIMITER $$
-- CREATE TRIGGER prevent_update_reservation_services
-- BEFORE UPDATE ON reservation_services
-- FOR EACH ROW
-- BEGIN
--     SIGNAL SQLSTATE '45000'
--     SET MESSAGE_TEXT = 'Обновление данных о заказанных услугах запрещено';
-- END$$
-- DELIMITER ;

-- Запрет на удаление заказанных услуг
-- DELIMITER $$
-- CREATE TRIGGER prevent_delete_reservation_services
-- BEFORE DELETE ON reservation_services
-- FOR EACH ROW
-- BEGIN
--     SIGNAL SQLSTATE '45000'
--     SET MESSAGE_TEXT = 'Удаление данных о заказанных услугах запрещено';
-- END$$
-- DELIMITER ;

-- Триггеры для оплаты
-- DELIMITER $$
-- CREATE TRIGGER set_total_payment
-- BEFORE INSERT ON payments
-- FOR EACH ROW
-- BEGIN
-- 	DECLARE remaining DECIMAL(10, 2);

-- 	SELECT amount_remaining INTO remaining
--     FROM reservations
--     WHERE reservation_id = NEW.reservation_id;

-- 	IF remaining = 0 THEN
--         SET @errorMsg = CONCAT('Нет неоплаченных счетов для: ', NEW.reservation_id);
--         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
--     END IF;

-- 	IF NEW.total = 0 THEN
-- 		SET NEW.total = remaining;
-- 	ELSEIF NEW.total > remaining THEN
-- 		SET @errorMsg = CONCAT('Сумма платежа (', NEW.total, 
--                               ') превышает оставшуюся сумму к оплате (', remaining, 
--                               ') для бронирования с ID: ', NEW.reservation_id, '.');
--         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @errorMsg;
-- 	END IF;
-- END$$
-- DELIMITER ;

-- DELIMITER $$
-- CREATE TRIGGER update_amounts_on_payment
-- AFTER INSERT ON payments
-- FOR EACH ROW
-- BEGIN
--     UPDATE reservations
--     SET amount_paid = amount_paid + NEW.total,
--         amount_remaining = amount_remaining - NEW.total
--     WHERE reservation_id = NEW.reservation_id;
-- END$$
-- DELIMITER ;

-- Запрет на обновление оплаты
-- DELIMITER $$
-- CREATE TRIGGER prevent_update_payments
-- BEFORE UPDATE ON payments
-- FOR EACH ROW
-- BEGIN
--     SIGNAL SQLSTATE '45000'
--     SET MESSAGE_TEXT = 'Обновление данных об оплате запрещено';
-- END$$
-- DELIMITER ;

-- Запрет на удаление оплаты
-- DELIMITER $$
-- CREATE TRIGGER prevent_delete_payments
-- BEFORE DELETE ON payments
-- FOR EACH ROW
-- BEGIN
--     SIGNAL SQLSTATE '45000'
--     SET MESSAGE_TEXT = 'Удаление данных об оплате запрещено';
-- END$$
-- DELIMITER ;

-- INSERT INTO rooms (number, double_bed, single_bed, class, area, price_per_night) VALUES
-- (1, 1, 0, 'Стандарт', 15, 3000),
-- (2, 1, 0, 'Стандарт', 15, 3000),
-- (3, 0, 2, 'Стандарт', 18, 3500),
-- (4, 0, 2, 'Стандарт', 18, 3500),
-- (5, 1, 2, 'Стандарт', 20, 4000),
-- (6, 1, 2, 'Стандарт', 20, 4000),
-- (7, 1, 0, 'Полулюкс', 35, 6000),
-- (8, 1, 0, 'Полулюкс', 35, 6000),
-- (9, 0, 2, 'Полулюкс', 38, 7500),
-- (10, 0, 2, 'Полулюкс', 38, 7500),
-- (11, 1, 2, 'Полулюкс', 40, 9000),
-- (12, 1, 2, 'Полулюкс', 40, 9000),
-- (13, 1, 0, 'Люкс', 55, 15000),
-- (14, 1, 0, 'Люкс', 55, 15000),
-- (15, 0, 2, 'Люкс', 58, 17500),
-- (16, 0, 2, 'Люкс', 58, 17500),
-- (17, 1, 2, 'Люкс', 60, 19000),
-- (18, 1, 2, 'Люкс', 60, 19000);

-- INSERT INTO guests (first_name, last_name, patronymic, passport, email, phone_number) VALUES
-- ('Иван', 'Иванов', 'Иванович', '1234 567890', 'ivan.ivanov@some_mail.com', '+79001234567'),
-- ('Мария', 'Петрова', 'Сергеевна', '2345 678901', 'maria.petrova@some_gmail.com', '+79007654321'),
-- ('Алексей', 'Сидоров', 'Алексеевич', '3456 789012', 'alexei.sidorov@some_mail.com', '+79001112233'),
-- ('Елена', 'Кузнецова', 'Дмитриевна', '4567 890123', 'elena.kuznetsova@some_gmail.com', '+79009876543'),
-- ('Дмитрий', 'Николаев', 'Андреевич', '5678 901234', 'dmitry.nikolaev@some_mail.com', '+79003216549'),
-- ('Ольга', 'Васильева', 'Викторовна', '6789 012345', 'olga.vasileva@some_gmail.com', '+79004567890'),
-- ('Андрей', 'Смирнов', 'Павлович', '7890 123456', 'andrey.smirnov@some_mail.com', '+79007894561'),
-- ('Татьяна', 'Морозова', 'Игоревна', '8901 234567', 'tatyana.morozova@some_gmail.com', '+79002345678'),
-- ('Сергей', 'Лебедев', 'Николаевич', '9012 345678', 'sergey.lebedev@some_mail.com', '+79008765432'),
-- ('Анна', 'Романова', 'Александровна', '0123 456789', 'anna.romanova@some_gmail.com', '+79005551234'),
-- ('Александр', 'Попов', 'Владимирович', '1122 334455', 'alexander.popov@some_mail.com', '+79001111111'),
-- ('Екатерина', 'Соколова', 'Анатольевна', '2233 445566', 'ekaterina.sokolova@some_gmail.com', '+79002222222'),
-- ('Максим', 'Кузнецов', 'Сергеевич', '3344 556677', 'maksim.kuznetsov@some_mail.com', '+79003333333'),
-- ('Олег', 'Федоров', 'Дмитриевич', '4455 667788', 'oleg.fedorov@some_gmail.com', '+79004444444'),
-- ('Наталья', 'Волкова', 'Олеговна', '5566 778899', 'natalya.volkova@some_mail.com', '+79005555555'),
-- ('Дарья', 'Иванова', 'Андреевна', '6677 889900', 'darya.ivanova@some_gmail.com', '+79006666666'),
-- ('Антон', 'Смирнов', 'Иванович', '7788 990011', 'anton.smirnov@some_gmail.com', '+79007777777'),
-- ('Юлия', 'Ковалева', 'Валерьевна', '8899 001122', 'yulia.kovaleva@some_mail.com', '+79008888888'),
-- ('Артем', 'Романов', 'Алексеевич', '9900 112233', 'artem.romanov@some_gmail.com', '+79009999999'),
-- ('Виктория', 'Лебедева', 'Сергеевна', '0011 223344', 'viktoria.lebedeva@some_gmail.com', '+79000000000');

-- INSERT INTO reservations (guest_id, room_id, check_in_date, check_out_date) VALUES
-- (1, 1, '2025-03-10', '2025-04-15'),
-- (2, 2, '2025-03-02', '2025-03-11'),
-- (3, 3, '2025-03-01', '2025-03-02'),
-- (4, 4, '2025-03-04', '2025-04-10'),
-- (5, 5, '2025-03-04', '2025-04-09'),
-- (6, 6, '2025-03-02', '2025-03-10'),
-- (7, 7, '2025-03-01', '2025-03-11'),
-- (8, 8, '2025-03-08', '2025-03-12'),
-- (9, 9, '2025-03-09', '2025-03-13'),
-- (10, 10, '2025-03-10', '2025-03-19'),
-- (11, 11, '2025-04-15', '2025-04-18'),
-- (12, 12, '2025-03-13', '2025-03-20'),
-- (13, 13, '2025-03-17', '2025-03-21'),
-- (14, 14, '2025-04-10', '2025-04-11'),
-- (15, 15, '2025-04-10', '2025-04-11'),
-- (16, 16, '2025-04-15', '2025-04-18'),
-- (17, 17, '2025-03-13', '2025-03-20'),
-- (18, 18, '2025-03-17', '2025-03-21'),
-- (19, 1, '2025-04-15', '2025-04-19'),
-- (20, 2, '2025-04-09', '2025-04-23');

-- Добавление услуг с фиксированной ценой
-- INSERT INTO services (service_name, description, price) VALUES
-- ('Неограниченный доступ к бассейну', 'Наслаждайтесь неограниченным доступом к бассейну, включая шезлонги и бар у бассейна.', 5000.00),
-- ('Неограниченный доступ в тренажерный зал', 'Получите доступ к тренажерному залу с возможностью занятий с личным тренером.', 3000.00),
-- ('Неограниченный доступ в СПА', 'Полный доступ ко всем услугам СПА, включая массажи, сауну и другие процедуры.', 10000.00),
-- ('Детская кроватка', 'Предоставление детской кроватки в номер для вашего малыша.', 1000.00),
-- ('Трансфер из/в аэропорт', 'Комфортабельный трансфер на автомобиле бизнес-класса от аэропорта.', 4500.00),
-- ('Личный доступ в Интернет', 'Подключим в вашем номере персональный высокоскоростной интернет для комфортного использования.', 5000.00);

-- Добавление услуг с нефиксированной ценой
-- INSERT INTO services (service_name, description, price, is_price_fixed) VALUES
-- ('Завтрак в номер', 'Наслаждайтесь вкусным завтраком, который мы доставим в ваш номер в удобное для вас время (с 8:00 до 11:00).', 1500.00, FALSE),
-- ('Обед в номер', 'Закажите обед, и мы принесем его в ваш номер в выбранное вами время (с 13:00 до 16:00).', 1500.00, FALSE),
-- ('Ужин в номер', 'Ужин в уютной обстановке вашего номера. Доставка в удобное для вас время (с 18:00 до 21:00).', 1500.00, FALSE),
-- ('Организация экскурсий', 'Мы полностью организуем для вас экскурсию в любое выбранное вами место. Подробности уточняйте у администратора.', 15000.00, FALSE),
-- ('Стирка и химчистка', 'Наши специалисты позаботятся о том, чтобы ваши вещи были безупречно чистыми и ухоженными. Цена указана за минимальный заказ.', 3000.00, FALSE),
-- ('Почасовая аренда конференц-зала', 'Идеальное пространство для проведения мероприятий.', 15000.00, FALSE),
-- ('Услуги няни', 'Профессиональная няня позаботится о вашем ребенке в удобное для вас время. Минимальное время заказа — 2 часа.', 4000.00, FALSE),
-- ('Почасовая аренда автомобиля', 'Предоставление автомобиля на выбор: эконом, комфорт или премиум класс. Подробности уточняйте у администратора.', 3500.00, FALSE),
-- ('Фотосессия в отеле', 'Профессиональный фотограф организует для вас фотосессию в интерьерах отеля или на территории. Включает 10 обработанных фото. Оплата почасовая.', 7500.00, FALSE);

-- Заказ услуг с фиксированной ценой
-- INSERT INTO reservation_services (reservation_id, service_id) VALUES 
-- (1, 1),
-- (1, 2),
-- (1, 3),
-- (1, 6),
-- (2, 1),
-- (3, 1),
-- (4, 1),
-- (5, 2),
-- (6, 3),
-- (7, 3),
-- (8, 6),
-- (8, 4),
-- (9, 1),
-- (10, 1);

--  Заказ услуг с нефиксированной ценой
-- INSERT INTO reservation_services (reservation_id, service_id, quantity) VALUES 
-- (1, 7, 2),
-- (1, 8, 1),
-- (1, 9, 1),
-- (2, 14, 5),
-- (2, 13, 6),
-- (2, 9, 2),
-- (3, 7, 1),
-- (3, 11, 1),
-- (3, 12, 4),
-- (4, 8, 2),
-- (4, 11, 1),
-- (4, 15, 3),
-- (5, 7, 2),
-- (5, 10, 2),
-- (5, 8, 2),
-- (6, 7, 2),
-- (6, 8, 2),
-- (6, 10, 2);

-- Оплата
-- INSERT INTO payments (reservation_id, payment_date, payment_method) VALUES
-- (1, '2025-03-10', 'Карта'),
-- (2, '2025-03-01', 'Онлайн'),
-- (3, '2025-03-01', 'Карта'),
-- (4, '2025-03-04', 'Наличные'),
-- (5, '2025-03-04', 'Карта'),
-- (6, '2025-03-02', 'Карта'),
-- (7, '2025-03-01', 'Карта'),
-- (8, '2025-03-08', 'Наличные'),
-- (9, '2025-03-09', 'Карта'),
-- (10, '2025-03-01', 'Онлайн'),
-- (11, '2025-03-01', 'Онлайн'),
-- (12, '2025-03-17', 'Онлайн'),
-- (13, '2025-03-08', 'Наличные'),
-- (14, '2025-04-10', 'Наличные'),
-- (15, '2025-04-10', 'Карта');



select * from reservations;