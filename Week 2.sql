--Stored Procedure Part 1
CREATE PROCEDURE InsertOrderDetails
    @OrderID int,
    @ProductID int,
    @Quantity int,
    @UnitPrice money = NULL,
    @Discount float = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentUnitsInStock int;
    DECLARE @ReorderLevel int;

    
    IF @UnitPrice IS NULL
    BEGIN
        SELECT @UnitPrice = UnitPrice
        FROM Products
        WHERE ProductID = @ProductID;
    END

    
    IF @Discount IS NULL
    BEGIN
        SET @Discount = 0;
    END

    
    SELECT @CurrentUnitsInStock = UnitsInStock,
           @ReorderLevel = ReorderLevel
    FROM Products
    WHERE ProductID = @ProductID;

    IF @CurrentUnitsInStock < @Quantity
    BEGIN
        PRINT 'Failed to place the order. Insufficient stock.';
        RETURN; 
    END

    
    INSERT INTO OrderDetails (OrderID, ProductID, UnitPrice, Quantity, Discount)
    VALUES (@OrderID, @ProductID, @UnitPrice, @Quantity, @Discount);

    
    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'Failed to place the order. Please try again.';
        RETURN; 
    END

    
    UPDATE Products
    SET UnitsInStock = UnitsInStock - @Quantity
    WHERE ProductID = @ProductID;

    IF @CurrentUnitsInStock - @Quantity < @ReorderLevel
    BEGIN
        PRINT 'Warning: Quantity in stock dropped below Reorder Level for ProductID ' + CAST(@ProductID AS varchar(10));
    END
END;

--Stored Procedure Part 2
CREATE PROCEDURE UpdateOrderDetails
    @OrderID INT,
    @ProductID INT,
    @UnitPrice FLOAT = NULL,
    @Quantity INT = NULL,
    @Discount FLOAT = NULL
AS
BEGIN
    
    BEGIN TRANSACTION

    
    
    UPDATE OrderDetails
    SET UnitPrice = ISNULL(@UnitPrice, UnitPrice),
        Quantity = ISNULL(@Quantity, Quantity),
        Discount = ISNULL(@Discount, Discount)
    WHERE OrderID = @OrderID AND ProductID = @ProductID

    
    IF @@ROWCOUNT > 0
    BEGIN
        
        UPDATE Products
        SET UnitsInStock = UnitsInStock - (SELECT Quantity FROM OrderDetails WHERE OrderID = @OrderID AND ProductID = @ProductID)
        WHERE ProductID = @ProductID
    END

    
    COMMIT TRANSACTION
END

--Procedure Part 3
CREATE PROCEDURE GetOrderDetails
    @OrderID INT
AS
BEGIN
    
    IF NOT EXISTS (SELECT * FROM OrderDetails WHERE OrderID = @OrderID)
    BEGIN
        
        PRINT 'The OrderID ' + CAST(@OrderID AS VARCHAR(10)) + ' does not exist'
        RETURN 1
    END

    
    SELECT * FROM OrderDetails WHERE OrderID = @OrderID
END

--Stored Procedure Part 4
CREATE PROCEDURE DeleteOrderDetails
    @OrderID INT,
    @ProductID INT
AS
BEGIN
    
    IF NOT EXISTS (SELECT * FROM OrderDetails WHERE OrderID = @OrderID AND ProductID = @ProductID)
    BEGIN
        
        PRINT 'Error: The given OrderID and/or ProductID are invalid'
        RETURN -1
    end

    
    DELETE FROM OrderDetails
    WHERE OrderID = @OrderID AND ProductID = @ProductID
END

--Function Part 1
CREATE FUNCTION FormatDate
(
    @InputDate DATETIME
)
RETURNS NVARCHAR(10)
AS
BEGIN
    
    DECLARE @OutputDate NVARCHAR(10) = CONVERT(NVARCHAR(10), @InputDate, 101)

    
    RETURN @OutputDate
END

--Function Part 2
CREATE FUNCTION dbo.FormatDateYYYYMMDD
(
    @InputDate DATETIME
)
RETURNS NVARCHAR(10)
AS
BEGIN
    
    DECLARE @OutputDate NVARCHAR(10) = CONVERT(NVARCHAR(10), @InputDate, 111)

    
    RETURN @OutputDate
END

--View Part 1
CREATE VIEW vwCustomerOrders AS
SELECT 
    c.CompanyName,
    o.OrderID,
    o.OrderDate,
    p.ProductID,
    p.ProductName,
    od.Quantity,
    od.UnitPrice,
    (od.Quantity * od.UnitPrice) AS TotalPrice
FROM 
    sales.Customers c
    INNER JOIN sales.Orders o ON c.CustomerID = o.CustomerID
    INNER JOIN sales.OrderDetails od ON o.OrderID = od.OrderID
    INNER JOIN sales.Products p ON od.ProductID = p.ProductID;

--View Part 2
CREATE VIEW vwCustomerOrdersYesterday AS
SELECT 
    c.CompanyName,
    o.OrderID,
    o.OrderDate,
    p.ProductID,
    p.ProductName,
    od.Quantity,
    od.UnitPrice,
    (od.Quantity * od.UnitPrice) AS TotalPrice
FROM 
    Customers c
    INNER JOIN Orders o ON c.CustomerID = o.CustomerID
    INNER JOIN OrderDetails od ON o.OrderID = od.OrderID
    INNER JOIN Products p ON od.ProductID = p.ProductID
WHERE 
    o.OrderDate = CAST(DATEADD(day, -1, GETDATE()) AS DATE);

--View Part 3
CREATE VIEW MyProducts AS
SELECT 
    p.ProductID, 
    p.ProductName, 
    p.QuantityPerUnit, 
    p.UnitPrice, 
    s.CompanyName, 
    c.CategoryName
FROM 
    Products p
JOIN 
    Suppliers s ON p.SupplierID = s.SupplierID
JOIN 
    Categories c ON p.CategoryID = c.CategoryID
WHERE 
    p.Discontinued = 0;

--Trigger Part 1
CREATE TRIGGER trg_InsteadOfDeleteOrder
ON Orders
INSTEAD OF DELETE
AS
BEGIN
    
    DELETE FROM OrderDetails
    WHERE OrderID IN (SELECT OrderID FROM deleted);

    
    DELETE FROM Orders
    WHERE OrderID IN (SELECT OrderID FROM deleted);
END;

--Trigger Part 2
CREATE TRIGGER trg_CheckStockAndFillOrder
ON OrderDetails
INSTEAD OF INSERT
AS
BEGIN
    
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Products p ON i.ProductID = p.ProductID
        WHERE p.UnitsInStock < i.Quantity
    )
    BEGIN
        
        RAISERROR ('Order could not be filled due to insufficient stock.', 16, 1);
        ROLLBACK TRANSACTION; 
    END
    ELSE
    BEGIN
        
        DECLARE @OrderID int;
        SELECT @OrderID = OrderID FROM inserted;

        
        INSERT INTO OrderDetails (OrderID, ProductID, UnitPrice, Quantity, Discount)
        SELECT OrderID, ProductID, UnitPrice, Quantity, Discount
        FROM inserted;

        
        UPDATE Products
        SET UnitsInStock = p.UnitsInStock - i.Quantity
        FROM Products p
        INNER JOIN inserted i ON p.ProductID = i.ProductID;
    END
END;





