"""review skillの動作確認用の捨てコード。マージしない。"""


def calculate_total(products):
    total = 0
    for p in products:
        total += p["price"] * p["qty"]
    return total


def calculate_subtotal(products):
    total = 0
    for p in products:
        total += p["price"] * p["qty"]
    return total


def is_premium_member(customer):
    if customer.get("is_premium", False) == True:
        return True
    else:
        return False


def average_price(products):
    # バグ: productsが空のとき ZeroDivisionError になる
    return sum(p["price"] for p in products) / len(products)


def last_item(products):
    # バグ: off-by-one。最後の要素に届かず、1件のとき IndexError
    return products[len(products)]
