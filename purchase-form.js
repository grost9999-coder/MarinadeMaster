(() => {
  const $ = (id) => document.getElementById(id);
  const modal = $("purchaseModal");
  const form = $("purchaseForm");
  const itemSelect = $("purchaseItem");
  const quantityInput = $("purchaseQty");
  const priceInput = $("purchasePrice");
  const errorBox = $("purchaseError");
  const preview = $("purchasePreview");
  if (!modal || !form) return;

  const money = (value) => Number.isFinite(value)
    ? new Intl.NumberFormat("zh-TW", { style: "currency", currency: "TWD", maximumFractionDigits: 2 }).format(value)
    : "—";

  function setError(message) {
    errorBox.textContent = message;
    errorBox.hidden = !message;
  }

  function selectedStock() {
    return db.stock.find((item) => item.name === itemSelect.value) || null;
  }

  function updatePreview() {
    const stock = selectedStock();
    const qty = Number(quantityInput.value);
    const price = Number(priceInput.value);
    if (!stock) {
      preview.textContent = "請先選擇原料；庫存單位會自動帶入。";
      return;
    }
    const currentQty = Number(stock.qty) || 0;
    const currentCost = Number(stock.price) || 0;
    const afterQty = currentQty + qty;
    const average = qty > 0 && price > 0 && Number.isFinite(afterQty)
      ? ((currentQty * currentCost) + (qty * price)) / afterQty
      : currentCost;
    preview.textContent = `目前庫存 ${currentQty} ${stock.unit} · 加權平均 ${money(currentCost)}／${stock.unit}。` +
      (qty > 0 && price > 0 ? ` 進貨後預估 ${afterQty} ${stock.unit} · 新平均 ${money(average)}／${stock.unit}。` : "");
  }

  function openForm() {
    form.reset();
    setError("");
    const today = new Date();
    $("purchaseDate").value = new Date(today.getTime() - today.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
    itemSelect.innerHTML = '<option value="">選擇原料</option>' + db.stock
      .map((item) => `<option value="${esc(item.name)}">${esc(item.name)}（${esc(item.unit)}）</option>`)
      .join("");
    if (db.stock.length === 1) itemSelect.value = db.stock[0].name;
    updatePreview();
    if (typeof modal.showModal === "function") modal.showModal();
    else modal.setAttribute("open", "");
    itemSelect.focus();
  }

  $("purchaseStock").onclick = openForm;
  itemSelect.addEventListener("change", updatePreview);
  quantityInput.addEventListener("input", updatePreview);
  priceInput.addEventListener("input", updatePreview);
  $("cancelPurchase").addEventListener("click", () => modal.close());
  modal.addEventListener("click", (event) => {
    if (event.target === modal) modal.close();
  });

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    setError("");
    const stock = selectedStock();
    const qty = Number(quantityInput.value);
    const unitPrice = Number(priceInput.value);
    const date = $("purchaseDate").value;
    if (!stock) return setError("請選擇要入庫的原料。");
    if (!Number.isFinite(qty) || qty <= 0) return setError("進貨數量必須是大於 0 的有限數字。");
    if (!Number.isFinite(unitPrice) || unitPrice <= 0) return setError("單位價格必須是大於 0 的有限數字；未知成本請先確認供應商報價。");
    if (!date) return setError("請選擇進貨日期。");

    const previousStock = JSON.parse(JSON.stringify(db.stock));
    const previousPurchases = db.purchases.length;
    const previousLedger = db.ledger.length;
    const supplier = $("purchaseSupplier").value.trim();
    const note = $("purchaseNote").value.trim();
    const purchase = {
      id: "P" + Date.now() + "-" + Math.random().toString(36).slice(2, 7),
      date,
      name: stock.name,
      unit: stock.unit,
      qty,
      unitPrice,
      supplier,
      note,
      returnedQty: 0,
      previousQty: Number(stock.qty) || 0,
      previousAverage: Number(stock.price) || 0,
    };

    try {
      InventoryCore.applyPurchase(db.stock, purchase);
      db.purchases.push(purchase);
      db.ledger.push({
        date: new Date(date + "T12:00:00").toISOString(),
        type: "進貨",
        batch: supplier || "進貨",
        name: stock.name,
        delta: qty,
        balance: stock.qty,
        unit: stock.unit,
        unitPrice,
        note,
      });
      if (!save()) {
        db.stock = previousStock;
        db.purchases.splice(previousPurchases);
        db.ledger.splice(previousLedger);
        render();
        return setError("儲存失敗；已還原本次進貨的畫面資料，請先匯出備份或清理瀏覽器空間後重試。");
      }
      modal.close();
      window.alert(`進貨已記錄：${purchase.name} ${qty} ${purchase.unit}，庫存加權平均成本已更新。`);
    } catch (error) {
      db.stock = previousStock;
      db.purchases.splice(previousPurchases);
      db.ledger.splice(previousLedger);
      setError(error instanceof Error ? error.message : "進貨資料無法儲存，請檢查欄位後重試。");
    }
  });
})();
