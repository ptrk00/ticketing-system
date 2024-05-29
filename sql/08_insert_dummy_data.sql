-- load test data
INSERT INTO "location" ("id", "name", "seats", "coordinates", "image_url", "description") VALUES
(1, 'Stage', 100, ST_GeogFromText('POINT(-70.935242 90.730610)'), 'https://cdn.pixabay.com/photo/2016/10/03/18/52/stage-1712494_1280.jpg', 'The Stage is an iconic venue known for its outstanding performances and vibrant atmosphere. It has a seating capacity of 100.'),
(2, 'AGH University', 150, ST_GeogFromText('POINT(19.92330738650622 50.06458216297299)'), 'https://www.uczelnie.pl/prezentacje/52/img/1_b.jpg', 'AGH University is a prestigious institution with modern facilities and a seating capacity of 150. It is renowned for its academic excellence.'),
(3, 'Mall', 200, ST_GeogFromText('POINT(-70.935242 10.730610)'), 'https://cdn.pixabay.com/photo/2016/05/26/05/12/shopping-mall-1416500_960_720.jpg', 'The Mall is a popular shopping destination with a variety of stores and a seating capacity of 200. It offers a great shopping experience.'),
(4, 'Random Museum', 250, ST_GeogFromText('POINT(-70.935242 20.730610)'), 'https://cdn.pixabay.com/photo/2017/04/05/01/10/natural-history-museum-2203648_1280.jpg', 'Random Museum showcases a diverse collection of exhibits and artifacts. With a seating capacity of 250, it provides an educational and cultural experience.'),
(5, 'Biblioteka UW', 300, ST_GeogFromText('POINT(21.02476929686503 52.24265017514509)'), 'https://cdn.pixabay.com/photo/2020/02/06/20/01/university-library-4825366_1280.jpg', 'Biblioteka UW is the University of Warsaw library. It has a seating capacity of 300 and offers a vast collection of books and resources for students.');


INSERT INTO "event" ("id", "name", "base_price", "base_price_currency", "start_date", "end_date", "seats", "location_id", "description", "genre", "image_url", "long_description") VALUES
(1, 'Music Concert', 200,'USD','2024-06-01', '2024-06-01', 100, 1, 'A grand music concert featuring famous bands.', 'art', 'https://cdn.pixabay.com/photo/2016/11/18/15/44/audience-1835431_960_720.jpg', 'This grand music concert features famous bands from all over the world. Attendees can expect a day full of musical performances, ranging from rock and pop to classical and jazz. The concert aims to bring together music enthusiasts and provide a platform for both emerging and established artists to showcase their talent. In addition to the main stage performances, there will be smaller, more intimate sessions in various corners of the venue, offering a variety of musical experiences. Food and beverages will be available from numerous vendors, ensuring that attendees can enjoy refreshments while listening to their favorite tunes. With its impressive lineup and vibrant atmosphere, this music concert is set to be an unforgettable event.'),
(2, 'Tech Conference', 200, 'PLN', '2024-07-15', '2024-07-17', 150, 2, 'Annual tech conference with keynotes and workshops.', 'buisness', 'https://cdn.pixabay.com/photo/2016/02/03/17/38/coffee-break-1177540_1280.jpg', 'The annual tech conference is a must-attend event for professionals in the technology industry. Over the course of three days, attendees will have the opportunity to attend keynote speeches by industry leaders, participate in hands-on workshops, and network with peers. The conference covers a wide range of topics, including artificial intelligence, cybersecurity, cloud computing, and more. Each day will feature a mix of presentations and interactive sessions designed to provide both theoretical knowledge and practical skills. Participants can also visit the exhibition hall, where leading tech companies will showcase their latest products and innovations. Whether you are a seasoned professional or new to the tech field, this conference offers valuable insights and opportunities for growth.'),
(3, 'Food Festival', 200, 'GBP', '2024-08-20', '2024-08-22', 200, 3, 'A festival showcasing gourmet food from around the world and musical.', 'sport', 'https://cdn.pixabay.com/photo/2014/10/19/20/59/hamburger-494706_960_720.jpg', 'The food festival is a culinary celebration that brings together gourmet food from around the world. Over the course of three days, attendees can sample dishes from various cuisines, each prepared by top chefs. In addition to the delicious food, the festival features musical performances that add to the festive atmosphere. Visitors can participate in cooking workshops, watch live demonstrations, and even meet some of their favorite chefs. There are also competitions where chefs showcase their skills and creativity. With its diverse offerings, the food festival is a perfect event for food lovers and anyone looking to enjoy a fun and flavorful experience.'),
(4, 'Art Exhibition', 200, 'PLN','2024-09-10', '2024-09-12', 250, 4, 'Exhibition of modern and contemporary art pieces.', 'art', 'https://cdn.pixabay.com/photo/2016/03/15/12/24/student-1258137_960_720.jpg', 'The art exhibition features a stunning collection of modern and contemporary art pieces. Over three days, visitors can explore a wide range of artworks, including paintings, sculptures, and installations. The exhibition aims to provide a platform for artists to showcase their work and for art enthusiasts to discover new and inspiring pieces. In addition to the displayed works, there will be guided tours, artist talks, and interactive sessions where visitors can engage with the art and the artists. The venue itself is designed to enhance the viewing experience, with carefully curated spaces that allow each piece to be appreciated fully. Whether you are an art aficionado or simply curious, this exhibition offers a rich and immersive experience.'),
(5, 'Book Fair', 200, 'EUR' ,'2024-10-05', '2024-10-07', 300, 5, 'A fair where you can find books from various genres and authors.', 'education', 'https://cdn.pixabay.com/photo/2020/04/17/08/03/books-5053733_960_720.jpg', 'The book fair is a literary event that brings together authors, publishers, and book lovers. Over three days, attendees can browse a wide selection of books from various genres and meet some of their favorite authors. The fair features book signings, panel discussions, and readings, providing a unique opportunity to engage with the literary community. In addition to the books, there will be workshops and seminars on topics such as writing, publishing, and storytelling. The event also includes activities for children, making it a family-friendly outing. Whether you are an avid reader or just looking for a fun and educational experience, the book fair has something to offer.'),
(6, 'Book Fair Super Exclusive', 200, 'USD' ,'2024-10-05', '2024-10-07', 50, 3, 'A fair where you can find super exclusive books from various genres and authors.', 'education', 'https://cdn.pixabay.com/photo/2014/09/05/18/32/old-books-436498_1280.jpg', 'The Book Fair Super Exclusive is a premium literary event designed for true book aficionados. Over the course of three days, this exclusive fair offers access to rare and limited-edition books from various genres, along with the chance to meet distinguished authors and publishers. Attendees can participate in intimate book signings, private readings, and exclusive panel discussions. The event also features specialized workshops focusing on rare book collection, preservation, and the art of bookbinding. With its limited seating and exclusive content, the Book Fair Super Exclusive provides a unique and luxurious experience for those passionate about literature. Whether you are a collector or a dedicated reader, this event offers unparalleled access to the world of exclusive books.');


INSERT INTO "user" (id, name, email, birthdate, registered_at) VALUES
(1, 'Alice Smith', 'alice.smith@example.com', '1990-01-15', '2021-07-07 01:06+10'::timestamptz),
(2, 'Bob Johnson', 'bob.johnson@example.com', '1985-05-23', '2021-02-02 01:06+10'::timestamptz),
(3, 'Charlie Brown', 'charlie.brown@example.com', '1992-08-12','2022-02-02 01:06+10'::timestamptz),
(4, 'Diana Prince', 'diana.prince@example.com', '1988-11-03', '2023-03-03 01:06+10'::timestamptz),
(5, 'Evan Davis', 'evan.davis@example.com', '1995-04-28', '2024-07-01 01:06+10'::timestamptz);

INSERT INTO "artist" (id, name, image_url) VALUES
(1, 'Vincent van Gogh', 'https://cdn.pixabay.com/photo/2015/08/02/23/38/agnar-hoeskuldsson-872408_1280.jpg'),
(2, 'Pablo Picasso', 'https://cdn.pixabay.com/photo/2016/11/29/01/34/man-1866572_1280.jpg'),
(3, 'Leonardo da Vinci', 'https://cdn.pixabay.com/photo/2015/08/05/10/40/andreas-kappus-876133_960_720.jpg'),
(4, 'Claude Monet', 'https://cdn.pixabay.com/photo/2015/08/05/10/41/andreas-kaufmann-876134_960_720.jpg'),
(5, 'Frida Kahlo', 'https://cdn.pixabay.com/photo/2018/04/05/09/32/portrait-3292287_1280.jpg');

INSERT INTO "event_artist" (event_id, artist_id) VALUES
(5, 1),
(4, 2),
(3, 3),
(2, 4),
(1, 5),
(2, 1);

INSERT INTO "ticket" (id, owner_id, event_id, price, currency, bought_at) VALUES
(1, 1, 5, 50.00, 'USD','2023-02-02 01:06+10'::timestamptz),
(2, 2, 4, 75.00, 'EUR','2023-03-03 02:05+10'::timestamptz), 
(3, 3, 3, 100.00, 'GBP','2022-07-12 03:04+10'::timestamptz),
(4, 4, 2, 120.00, 'PLN','2023-08-10 04:03+10'::timestamptz), 
(5, 5, 1, 60.00, 'USD','2023-09-11 05:02+10'::timestamptz),
(6, 3, 1, 90.00, 'GBP','2024-01-01 06:01+10'::timestamptz),
(7, 3, 6, 190.00, 'GBP', NOW());

-- adjust sequence due to manually inserted ids
SELECT setval(pg_get_serial_sequence('"ticket"', 'id'), MAX(id)) FROM "ticket";
SELECT setval(pg_get_serial_sequence('"event"', 'id'), MAX(id)) FROM "event";