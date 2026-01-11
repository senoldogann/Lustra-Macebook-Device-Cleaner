# Lustra'ya Katkıda Bulunma Rehberi (Contributing) 👋

Öncelikle Lustra projesine ilgi gösterdiğiniz için teşekkürler! Bu projenin amacı macOS kullanıcıları için hızlı, güvenli ve estetik bir temizlik aracı sunmaktır.

Açık kaynak felsefesine inanıyoruz, ancak kod kalitesini ve proje bütünlüğünü korumak için bazı kurallarımız var.

---

## 🚀 Nasıl Katkıda Bulunabilirim?

### 1. Issue Açın (Önce Tartışalım)
Büyük bir değişiklik yapmadan önce (yeni özellik, büyük refactor) lütfen bir **Issue** açarak fikrinizi belirtin.
- Küçük bug fix'ler için direkt PR açabilirsiniz.
- Büyük özellikler için önce onay almanız, boşuna kod yazmanızı engeller.

### 2. Fork & Branch
Direkt `main` branch'ine push yapamazsınız (Koruma altındadır).
1.  Projeyi **Fork**'layın.
2.  Kendi repozitorinizde geliştirme yapın.
3.  Branch isimlendirmeniz şu formatta olsun:
    - Feature: `feature/yeni-ozellik-adi`
    - Fix: `fix/hata-adi`
    - Chore: `chore/temizlik`

### 3. Pull Request (PR) Gönderin
Geliştirmeniz bittiğinde **Pull Request** açın.
- PR şablonunu dikkatlice doldurun.
- "Bu PR ne yapıyor?" sorusuna net cevap verin.
- Eğer bir Issue'yu çözüyorsa `Closes #123` şeklinde belirtin.

---

## 🛠 Teknik Kurallar

1.  **SwiftLint:** Projede SwiftLint aktiftir. Kodu göndermeden önce lint hatalarını çözdüğünüzden emin olun.
2.  **SwiftUI:** UI geliştirmelerinde `Design System` (Renkler, Fontlar) dışına çıkmamaya çalışın.
3.  **Testler:** Kritik fonksiyonlara Unit Test yazılması beklenir.

---

## ✅ Code of Conduct (Davranış Kuralları)

Lütfen saygılı ve yapıcı olun. Herkes hata yapabilir, önemli olan birlikte öğrenmek ve gelişmektir.

Katkılarınız için şimdiden teşekkürler! 🎉
