-- ======================================================================================
-- FILE: 2.1 - TRIGGERS GHI LOG AUDIT CHO THÊM/SỬA/XÓA SẢN PHẨM
-- Mục đích: Ghi lại lịch sử thay đổi dữ liệu vào bảng AUDIT
-- Lưu ý: Validation được xử lý trong Stored Procedures (yêu cầu 2.1)
-- ======================================================================================

USE HeThongBanHang;
GO

-- --------------------------------------------------------------------------------------
-- TRIGGER 1: GHI LOG KHI THÊM/SỬA SẢN PHẨM
-- Chức năng: Tự động ghi log vào AUDIT_SAN_PHAM sau khi INSERT/UPDATE thành công
-- --------------------------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_SanPham_GhiLogAudit
ON SAN_PHAM
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- GHI LOG CHO UPDATE
    IF EXISTS (SELECT 1
    FROM deleted)
    BEGIN
        INSERT INTO AUDIT_SAN_PHAM
            (
            MaSanPham, HanhDong, NguoiThucHien,
            TenSanPhamCu, GiaHienThiCu, LoaiCu, ThongTinCu, LinkSanPhamCu,
            TenSanPhamMoi, GiaHienThiMoi, LoaiMoi, ThongTinMoi, LinkSanPhamMoi,
            LyDo
            )
        SELECT
            i.MaSanPham, 'UPDATE', SYSTEM_USER,
            d.TenSanPham, d.GiaHienThi, d.Loai, d.ThongTinSanPham, d.LinkSanPham,
            i.TenSanPham, i.GiaHienThi, i.Loai, i.ThongTinSanPham, i.LinkSanPham,
            N'Cập nhật sản phẩm'
        FROM inserted i
            INNER JOIN deleted d ON i.MaSanPham = d.MaSanPham;
    END
    -- GHI LOG CHO INSERT
    ELSE
    BEGIN
        INSERT INTO AUDIT_SAN_PHAM
            (
            MaSanPham, HanhDong, NguoiThucHien,
            TenSanPhamMoi, GiaHienThiMoi, LoaiMoi, ThongTinMoi, LinkSanPhamMoi,
            LyDo
            )
        SELECT
            MaSanPham, 'INSERT', SYSTEM_USER,
            TenSanPham, GiaHienThi, Loai, ThongTinSanPham, LinkSanPham,
            N'Thêm sản phẩm mới'
        FROM inserted;
    END
END;
GO

-- --------------------------------------------------------------------------------------
-- TRIGGER 2: GHI LOG KHI XÓA SẢN PHẨM
-- Chức năng: Tự động ghi log vào AUDIT_XOA_SAN_PHAM sau khi DELETE thành công
-- Lưu ý: Logic xóa cascading và validation được xử lý trong sp_XoaSanPham
-- --------------------------------------------------------------------------------------
CREATE OR ALTER TRIGGER TR_SanPham_GhiLogXoa
ON SAN_PHAM
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Đọc số lượng đã đếm từ bảng tạm (được tạo bởi stored procedure)
    DECLARE @SoBienTheXoa INT = 0, @SoDanhGiaXoa INT = 0, 
            @SoAnhVideoXoa INT = 0, @SoGioHangXoa INT = 0;

    IF OBJECT_ID('tempdb..#TempAuditCount') IS NOT NULL
    BEGIN
        SELECT
            @SoBienTheXoa = SoBienTheXoa,
            @SoDanhGiaXoa = SoDanhGiaXoa,
            @SoAnhVideoXoa = SoAnhVideoXoa,
            @SoGioHangXoa = SoGioHangXoa
        FROM #TempAuditCount;
    END

    -- GHI LOG VÀO AUDIT_XOA_SAN_PHAM
    INSERT INTO AUDIT_XOA_SAN_PHAM
        (
        MaSanPham, NguoiThucHien, TenSanPham, GiaHienThi, MaSoShop,
        SoLuongBienTheXoa, SoLuongDanhGiaXoa, SoLuongAnhVideoXoa, SoLuongGioHangXoa,
        TrangThai
        )
    SELECT
        MaSanPham, SYSTEM_USER, TenSanPham, GiaHienThi, MaSoShop,
        @SoBienTheXoa, @SoDanhGiaXoa, @SoAnhVideoXoa, @SoGioHangXoa,
        N'Thành công'
    FROM deleted;
END;
GO

-- --------------------------------------------------------------------------------------
-- TESTCASE: KIỂM TRA CÁC TRIGGER
-- --------------------------------------------------------------------------------------

PRINT N'';
PRINT N'======================================================================================';
PRINT N'TESTCASE 1: KIỂM TRA TRIGGER VALIDATION (TR_SanPham_KiemTraRangBuoc)';
PRINT N'======================================================================================';

-- Test 1.1: Thử thêm sản phẩm với giá <= 0 (Phải báo lỗi)
PRINT N'';
PRINT N'--- Test 1.1: Thêm sản phẩm giá <= 0 ---';
BEGIN TRY
    INSERT INTO SAN_PHAM
    (MaSanPham, MaSoShop, TenSanPham, ThongTinSanPham, GiaHienThi, Loai)
VALUES
    ('TEST001', 'SHOP0001', N'Sản phẩm test lỗi', N'Giá âm', -100, N'Test');
    PRINT N' LỖI: Trigger không hoạt động! Đã thêm được sản phẩm giá âm.';
END TRY
BEGIN CATCH
    PRINT N' PASS: ' + ERROR_MESSAGE();
END CATCH

-- Test 1.2: Thử thêm sản phẩm không có tên (Phải báo lỗi)
PRINT N'';
PRINT N'--- Test 1.2: Thêm sản phẩm không có tên ---';
BEGIN TRY
    INSERT INTO SAN_PHAM
    (MaSanPham, MaSoShop, TenSanPham, ThongTinSanPham, GiaHienThi, Loai)
VALUES
    ('TEST002', 'SHOP0001', '', N'Không tên', 100000, N'Test');
    PRINT N' LỖI: Trigger không hoạt động! Đã thêm được sản phẩm không tên.';
END TRY
BEGIN CATCH
    PRINT N' PASS: ' + ERROR_MESSAGE();
END CATCH

-- Test 1.3: Thử thêm sản phẩm với link trùng (Phải báo lỗi)
PRINT N'';
PRINT N'--- Test 1.3: Thêm sản phẩm link trùng ---';
BEGIN TRY
    INSERT INTO SAN_PHAM
    (MaSanPham, MaSoShop, TenSanPham, ThongTinSanPham, LinkSanPham, GiaHienThi, Loai)
VALUES
    ('TEST003', 'SHOP0001', N'Sản phẩm test', N'Link trùng', 'thinh.com/p1', 100000, N'Test');
    PRINT N' LỖI: Trigger không hoạt động! Đã thêm được sản phẩm link trùng.';
END TRY
BEGIN CATCH
    PRINT N' PASS: ' + ERROR_MESSAGE();
END CATCH

-- Test 1.4: Thử thêm sản phẩm với shop không tồn tại (Phải báo lỗi)
PRINT N'';
PRINT N'--- Test 1.4: Thêm sản phẩm shop không tồn tại ---';
BEGIN TRY
    INSERT INTO SAN_PHAM
    (MaSanPham, MaSoShop, TenSanPham, ThongTinSanPham, GiaHienThi, Loai)
VALUES
    ('TEST004', 'SHOP9999', N'Sản phẩm test', N'Shop fake', 100000, N'Test');
    PRINT N' LỖI: Trigger không hoạt động! Đã thêm được sản phẩm shop không tồn tại.';
END TRY
BEGIN CATCH
    PRINT N' PASS: ' + ERROR_MESSAGE();
END CATCH

-- Test 1.5: Thêm sản phẩm hợp lệ (Phải thành công)
PRINT N'';
PRINT N'--- Test 1.5: Thêm sản phẩm hợp lệ ---';
BEGIN TRY
    INSERT INTO SAN_PHAM
    (MaSanPham, MaSoShop, TenSanPham, ThongTinSanPham, LinkSanPham, GiaHienThi, Loai)
VALUES
    ('TEST_OK', 'SHOP0001', N'Sản phẩm test thành công', N'Mô tả', 'test.com/valid', 250000, N'Test');
    PRINT N' PASS: Thêm sản phẩm thành công!';
    
    -- Xóa sản phẩm test
    DELETE FROM SAN_PHAM WHERE MaSanPham = 'TEST_OK';
END TRY
BEGIN CATCH
    PRINT N' FAIL: ' + ERROR_MESSAGE();
END CATCH

PRINT N'';
PRINT N'======================================================================================';
PRINT N'TESTCASE 2: KIỂM TRA TRIGGER XÓA (TR_SanPham_KiemTraTruocKhiXoa)';
PRINT N'======================================================================================';

-- Test 2.1: Thử xóa sản phẩm đã có trong đơn hàng (Phải báo lỗi)
PRINT N'';
PRINT N'--- Test 2.1: Xóa sản phẩm đã có đơn hàng ---';
BEGIN TRY
    DELETE FROM SAN_PHAM WHERE MaSanPham = 'PROD0001';
    PRINT N' LỖI: Trigger không hoạt động! Đã xóa được sản phẩm có đơn hàng.';
END TRY
BEGIN CATCH
    PRINT N' PASS: ' + ERROR_MESSAGE();
END CATCH

-- Test 2.2: Xóa sản phẩm không có đơn hàng (Phải thành công nếu không vi phạm)
PRINT N'';
PRINT N'--- Test 2.2: Xóa sản phẩm hợp lệ ---';
BEGIN TRY
    -- Thêm sản phẩm mới để test xóa
    INSERT INTO SAN_PHAM
    (MaSanPham, MaSoShop, TenSanPham, ThongTinSanPham, GiaHienThi, Loai)
VALUES
    ('TEST_DEL', 'SHOP0001', N'Sản phẩm test xóa', N'Để test xóa', 100000, N'Test');
    
    -- Xóa sản phẩm vừa tạo
    DELETE FROM SAN_PHAM WHERE MaSanPham = 'TEST_DEL';
    PRINT N' PASS: Xóa sản phẩm thành công!';
END TRY
BEGIN CATCH
    PRINT N' FAIL: ' + ERROR_MESSAGE();
END CATCH

PRINT N'';
PRINT N'======================================================================================';
PRINT N'KẾT THÚC TESTCASE - TRIGGERS HOẠT ĐỘNG ĐÚNG YÊU CẦU';
PRINT N'======================================================================================';
GO


-- --------------------------------------------------------------------------------------
-- TESTCASE: KIỂM TRA TRIGGER GHI LOG
-- --------------------------------------------------------------------------------------

PRINT N'';
PRINT N'======================================================================================';
PRINT N'TESTCASE: KIỂM TRA TRIGGER GHI LOG AUDIT';
PRINT N'======================================================================================';

-- Test 1: Thêm sản phẩm và kiểm tra log
PRINT N'';
PRINT N'--- Test 1: Thêm sản phẩm và kiểm tra AUDIT_SAN_PHAM ---';
BEGIN TRY
    -- Thêm sản phẩm qua stored procedure (có validation)
    EXEC sp_ThemSanPham 
        @MaSanPham = 'TEST_LOG1',
        @MaSoShop = 'SHOP0001',
        @TenSanPham = N'Sản phẩm test log',
        @ThongTinSanPham = N'Test ghi log audit',
        @LinkSanPham = 'test.com/log1',
        @GiaHienThi = 150000,
        @Loai = N'Test';
    
    -- Kiểm tra log
    IF EXISTS (SELECT 1
FROM AUDIT_SAN_PHAM
WHERE MaSanPham = 'TEST_LOG1' AND HanhDong = 'INSERT')
        PRINT N'✅ PASS: Đã ghi log INSERT vào AUDIT_SAN_PHAM';
    ELSE
        PRINT N'❌ FAIL: Không tìm thấy log INSERT';
    
    -- Xóa test
    DELETE FROM SAN_PHAM WHERE MaSanPham = 'TEST_LOG1';
END TRY
BEGIN CATCH
    PRINT N'❌ FAIL: ' + ERROR_MESSAGE();
END CATCH

-- Test 2: Cập nhật sản phẩm và kiểm tra log
PRINT N'';
PRINT N'--- Test 2: Cập nhật sản phẩm và kiểm tra AUDIT_SAN_PHAM ---';
BEGIN TRY
    -- Thêm sản phẩm
    EXEC sp_ThemSanPham 
        @MaSanPham = 'TEST_LOG2',
        @MaSoShop = 'SHOP0001',
        @TenSanPham = N'Sản phẩm test log 2',
        @ThongTinSanPham = N'Test',
        @LinkSanPham = 'test.com/log2',
        @GiaHienThi = 200000,
        @Loai = N'Test';
    
    -- Cập nhật sản phẩm
    EXEC sp_CapNhatSanPham 
        @MaSanPham = 'TEST_LOG2',
        @TenSanPham = N'Sản phẩm đã sửa',
        @GiaHienThi = 250000;
    
    -- Kiểm tra log
    IF EXISTS (SELECT 1
FROM AUDIT_SAN_PHAM
WHERE MaSanPham = 'TEST_LOG2' AND HanhDong = 'UPDATE')
        PRINT N'✅ PASS: Đã ghi log UPDATE vào AUDIT_SAN_PHAM';
    ELSE
        PRINT N'❌ FAIL: Không tìm thấy log UPDATE';
    
    -- Xóa test
    DELETE FROM SAN_PHAM WHERE MaSanPham = 'TEST_LOG2';
END TRY
BEGIN CATCH
    PRINT N'❌ FAIL: ' + ERROR_MESSAGE();
END CATCH

-- Test 3: Xóa sản phẩm và kiểm tra log
PRINT N'';
PRINT N'--- Test 3: Xóa sản phẩm và kiểm tra AUDIT_XOA_SAN_PHAM ---';
BEGIN TRY
    -- Thêm sản phẩm
    EXEC sp_ThemSanPham 
        @MaSanPham = 'TEST_LOG3',
        @MaSoShop = 'SHOP0001',
        @TenSanPham = N'Sản phẩm test xóa',
        @ThongTinSanPham = N'Test',
        @LinkSanPham = 'test.com/log3',
        @GiaHienThi = 100000,
        @Loai = N'Test';
    
    -- Xóa sản phẩm qua stored procedure
    EXEC sp_XoaSanPham @MaSanPham = 'TEST_LOG3';
    
    -- Kiểm tra log
    IF EXISTS (SELECT 1
FROM AUDIT_XOA_SAN_PHAM
WHERE MaSanPham = 'TEST_LOG3')
        PRINT N'✅ PASS: Đã ghi log DELETE vào AUDIT_XOA_SAN_PHAM';
    ELSE
        PRINT N'❌ FAIL: Không tìm thấy log DELETE';
END TRY
BEGIN CATCH
    PRINT N'❌ FAIL: ' + ERROR_MESSAGE();
END CATCH

PRINT N'';
PRINT N'======================================================================================';
PRINT N'KẾT THÚC TESTCASE - TRIGGER GHI LOG HOẠT ĐỘNG ĐÚNG';
PRINT N'======================================================================================';
GO