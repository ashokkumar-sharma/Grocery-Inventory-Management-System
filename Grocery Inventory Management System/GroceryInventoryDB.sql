CREATE TABLE Product
(
	ProductID INT IDENTITY NOT NULL,
	ProdName VARCHAR(50) NOT NULL,
	prodUnitPrice INT NOT NULL,
	Threshold INT NOT NULL,
	CONSTRAINT Products_PK PRIMARY KEY (ProductID)
);

CREATE TABLE StoreMgr
(
	ManagerID INT IDENTITY NOT NULL,
	MFName VARCHAR(30) NOT NULL,
	MLName VARCHAR(30) NOT NULL,
	MPhone VARCHAR(12) NOT NULL,
	MEmailAddr VARCHAR(30),
	CONSTRAINT StoreMgr_PK PRIMARY KEY (ManagerID)
);

CREATE TABLE ProdInstance
(
	ProdInstanceID INT IDENTITY NOT NULL,
	ProductID INT NOT NULL,
	Sell_by_date DATE NOT NULL,
	quantAvailable INT NOT NULL,
	CONSTRAINT ProdInstance_PK PRIMARY KEY (ProdInstanceID),
	CONSTRAINT ProdInstance_FK FOREIGN KEY (ProductID) REFERENCES Product (ProductID)
);

CREATE TABLE DiscardedProd
(
	DiscardID INT IDENTITY NOT NULL,
	ProdInstanceID INT NOT NULL,
	dateDiscarded DATE DEFAULT getdate() NOT NULL,
	quantDiscard INT NOT NULL DEFAULT 0,
	CONSTRAINT DiscardedProd_PK PRIMARY KEY (DiscardID, ProdInstanceID),
	CONSTRAINT DiscardedProd_FK FOREIGN KEY (ProdInstanceID) REFERENCES ProdInstance (ProdInstanceID) 
);

CREATE TABLE SalesOrder
(
	SOrderID INT IDENTITY NOT NULL,
	ManagerID INT NOT NULL,
	saleDate DATE DEFAULT getdate() NOT NULL,
	CONSTRAINT SalesOrder_PK PRIMARY KEY (SOrderID),
	CONSTRAINT SalesOrder_FK FOREIGN KEY (ManagerID) REFERENCES StoreMgr (ManagerID)
);

CREATE TABLE SalesOrderline
(
	SOrderlineID INT IDENTITY NOT NULL,
	SOrderID INT NOT NULL,
	ProdInstanceID INT NOT NULL,
	soldQuantity INT NOT NULL,
	totalPrice INT DEFAULT 0 NOT NULL,
	CONSTRAINT SalesOrderline_PK PRIMARY KEY (SOrderlineID),
	CONSTRAINT SalesOrderline_FK1 FOREIGN KEY (SOrderID) REFERENCES SalesOrder (SOrderID),
	CONSTRAINT SalesOrderline_FK2 FOREIGN KEY (ProdInstanceID) REFERENCES ProdInstance (ProdInstanceID)
);

CREATE TABLE Vendor
(
	VendorID INT IDENTITY NOT NULL,
	CompanyName VARCHAR(200) NOT NULL,
	VPhone VARCHAR(12) NOT NULL,
	VEmailAddr VARCHAR(30),
	CONSTRAINT Vendor_PK PRIMARY KEY (VendorID)
);

CREATE TABLE PurchaseOrder
(
	POrderID INT IDENTITY NOT NULL,
	ManagerID INT NOT NULL,
	VendorID INT NOT NULL,
	dateofOrder DATE DEFAULT getdate() NOT NULL,
	CONSTRAINT PurchaseOrder_PK PRIMARY KEY (POrderID),
	CONSTRAINT PurchaseOrder_FK1 FOREIGN KEY (ManagerID) REFERENCES StoreMgr(ManagerID),
	CONSTRAINT PurchaseOrder_FK2 FOREIGN KEY (VendorID) REFERENCES Vendor(VendorID)
);

CREATE TABLE RestockOrderline
(
	ROrderlineID INT IDENTITY NOT NULL,
	POrderID INT NOT NULL,
	ProductID INT NOT NULL,
	purchaseQuantity INT NOT NULL,
	CONSTRAINT RestockOrderline_PK PRIMARY KEY (ROrderlineID),
	CONSTRAINT RestockOrderline_FK1 FOREIGN KEY (POrderID) REFERENCES PurchaseOrder (POrderID),
	CONSTRAINT RestockOrderline_FK2 FOREIGN KEY (ProductID) REFERENCES Product (ProductID),
);

GO
CREATE TRIGGER trgInsertDiscard
ON ProdInstance
FOR INSERT
AS
INSERT INTO DiscardedProd (ProdInstanceID)
SELECT ProdInstanceID
FROM ProdInstance p
WHERE p.Sell_by_date <= getdate() AND p.ProdInstanceID NOT IN(
	SELECT ProdInstanceID
	FROM DiscardedProd
)

GO
CREATE TRIGGER trgUpdateProdInstance1
ON DiscardedProd
AFTER INSERT 
AS
UPDATE dp
SET dp.quantDiscard = pri.quantAvailable
FROM ProdInstance pri
JOIN DiscardedProd dp
ON pri.ProdInstanceID = dp.ProdInstanceID
JOIN inserted i
ON i.DiscardID = dp.DiscardID
WHERE dp.DiscardID = i.DiscardID
UPDATE pri
SET quantAvailable = 0
FROM ProdInstance pri
JOIN DiscardedProd dp
ON pri.ProdInstanceID = dp.ProdInstanceID
JOIN inserted i
ON i.DiscardID = dp.DiscardID
WHERE dp.DiscardID = i.DiscardID;

drop trigger trgUpdateProdInstance1
GO
CREATE TRIGGER trgUpdateProdInstance2
ON SalesOrderline
AFTER INSERT
AS 
UPDATE ProdInstance
SET quantAvailable = quantAvailable - QA.soldQuantity
FROM
(
	SELECT i.soldQuantity, i.ProdInstanceID
	FROM inserted i
	JOIN ProdInstance pri
	ON i.ProdInstanceID = pri.ProdInstanceID
	JOIN SalesOrderline so
	ON i.SOrderlineID = so.SOrderlineID
) QA
WHERE ProdInstance.ProdInstanceID = QA.ProdInstanceID

GO
CREATE TRIGGER trgUpdateSalesOrderline
ON SalesOrderline
AFTER INSERT 
AS 
UPDATE so 
SET so.totalPrice = p.prodUnitPrice*so.soldQuantity
FROM SalesOrderline so
JOIN ProdInstance pri
ON pri.ProdInstanceID = so.ProdInstanceID
JOIN Product p
ON p.ProductID = pri.ProductID

ALTER TABLE Product
DROP COLUMN Threshold;

ALTER TABLE Product
ADD Threshold INT DEFAULT 0 NOT NULL;

GO
CREATE TRIGGER trgUpdateProduct
ON SalesOrderline
AFTER UPDATE
AS
UPDATE Product
SET Product.Threshold = TH.value/6
FROM 
(
	SELECT DISTINCT p.ProductID, SUM(so.soldQuantity) AS value	
	FROM SalesOrderline so	
	JOIN ProdInstance pri
	ON so.ProdInstanceID = pri.ProdInstanceID
	JOIN Product p
	ON pri.ProductID = p.ProductID
	GROUP BY p.ProductID
) TH
WHERE Product.ProductID = TH.ProductID

GO
CREATE VIEW abc
AS
SELECT DISTINCT p.ProductID, p.ProdName, SUM(so.soldQuantity) Total
FROM SalesOrderline so
LEFT JOIN ProdInstance pri
ON so.ProdInstanceID = pri.ProdInstanceID
JOIN Product p
ON pri.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProdName

select * from abc

GO
CREATE VIEW Suggest
AS	
SELECT p.ProdName, p.Threshold, TH.value QS
FROM Product p
JOIN ProdInstance pri
ON p.ProductID = pri.ProductID
JOIN
(
	SELECT DISTINCT p.ProductID, SUM(so.soldQuantity) AS value	
	FROM SalesOrderline so	
	JOIN ProdInstance pri
	ON so.ProdInstanceID = pri.ProdInstanceID
	JOIN Product p
	ON pri.ProductID = p.ProductID
	GROUP BY p.ProductID
) TH
ON TH.ProductID = pri.ProductID
WHERE p.ProductID = TH.ProductID
GROUP BY p.ProductID, p.ProdName, p.Threshold, TH.value
HAVING SUM(pri.quantAvailable) < p.Threshold
drop view Suggest
select * from Suggest

SELECT * FROM Product

SELECT ProdName, Threshold 
FROM Product 