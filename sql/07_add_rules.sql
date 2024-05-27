-- rule to not delete ticket, mark it as revoked instead
CREATE RULE revoke_instead_of_delete_ticket AS 
    ON DELETE TO ticket
        DO INSTEAD
            UPDATE ticket SET revoked = TRUE WHERE id = OLD.id;