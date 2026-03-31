// lib/features/disaster_mode/data/pfa_messages.dart
// Turkish PFA messages based on WHO PFA, NCTSN PFA Field Guide principles.
// Empathetic, realistic, non-judgmental, culturally neutral.
// No religious/political content, no definite rescue promises.

enum PfaCategory {
  firstContact, // İlk temas / mesaj alındı
  panicBreathing, // Yüksek panik ve nefes darlığı
  hopelessness, // Umutsuzluk ve çaresizlik
  loneliness, // Yalnızlık ve terk edilmişlik
  painTrapped, // Şiddetli ağrı veya sıkışma
  uncertainty, // Bilgi belirsizliği / dış dünyaya dair kaygı
}

class PfaMessage {
  final String text;
  final List<String> psychologicalFunctions;
  final String pfaComponent;
  final PfaCategory category;
  final int vulnerabilityPriority; // 0=all, 1=prefer for vulnerable groups

  const PfaMessage({
    required this.text,
    required this.psychologicalFunctions,
    required this.pfaComponent,
    required this.category,
    this.vulnerabilityPriority = 0,
  });
}

class PfaMessages {
  PfaMessages._();

  static const List<PfaMessage> all = [
    // ─── İlk Temas ───────────────────────────────────────────────────────
    PfaMessage(
      text: 'Mesajınız ulaştı. Nerede olduğunuz biliniyor, ekipler harekete geçti.',
      psychologicalFunctions: ['güvenlik ve görülme hissi', 'kaygı azaltma'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.firstContact,
    ),
    PfaMessage(
      text: 'Sesinizi duyduk. Şu an için en önemli şey sakin kalmak ve enerji korumak.',
      psychologicalFunctions: ['güvenlik', 'öz-etkinlik'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.firstContact,
    ),
    PfaMessage(
      text: 'Bilgileriniz kaydedildi. Yardım yolda, sizi unutmadık.',
      psychologicalFunctions: ['güvenlik ve görülme hissi', 'sosyal bağlılık'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.firstContact,
    ),
    PfaMessage(
      text: 'Burada olduğunuzu biliyoruz. Durumunuzu düzenli olarak paylaşmaya devam edin.',
      psychologicalFunctions: ['öz-etkinlik', 'kontrol duygusu'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.firstContact,
    ),
    PfaMessage(
      text: 'Mesajınız alındı. Şu an yapabileceğiniz en iyi şey yavaş nefes alıp kendinizi korumak.',
      psychologicalFunctions: ['sakinleşme', 'öz-etkinlik'],
      pfaComponent: 'Calming',
      category: PfaCategory.firstContact,
    ),

    // ─── Yüksek Panik ve Nefes Darlığı ──────────────────────────────────
    PfaMessage(
      text:
          'Şu an çok zor bir anda olduğunuzu biliyoruz. Burnunuzdan yavaşça nefes alın, ağzınızdan verin.',
      psychologicalFunctions: ['panik azaltma', 'sakinleşme'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),
    PfaMessage(
      text:
          '4 sayarak nefes alın, 4 tutun, 4 sayarak verin. Bu iki kez tekrar edin — bedeniniz yavaşlayacak.',
      psychologicalFunctions: ['panik azaltma', 'öz-etkinlik'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),
    PfaMessage(
      text:
          'Nefes darlığı hissediyorsanız bu normaldir; bedeniniz sizi korumaya çalışıyor. Yavaş nefes almak yardımcı olur.',
      psychologicalFunctions: ['duyguları normalleştirme', 'sakinleşme'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),
    PfaMessage(
      text:
          'Gözlerinizi kapatıp elinizi göğsünüze koyun. Nefes alırken elinizdeki hareketi hissedin. Tekrar edin.',
      psychologicalFunctions: ['panik azaltma', 'sakinleşme'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),
    PfaMessage(
      text: 'Bu his geçici. Bedeniniz şu an alarm veriyor ama siz bu durumu atlatabilirsiniz.',
      psychologicalFunctions: ['duyguları normalleştirme', 'gerçekçi umut'],
      pfaComponent: 'Calming',
      category: PfaCategory.panicBreathing,
    ),

    // ─── Umutsuzluk ve Çaresizlik ────────────────────────────────────────
    PfaMessage(
      text:
          'Bu kadar zor bir anda böyle hissetmek anlaşılır bir tepki. Sizin için endişelenen insanlar var.',
      psychologicalFunctions: ['duyguları normalleştirme', 'sosyal bağlılık'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.hopelessness,
    ),
    PfaMessage(
      text: 'Şu an sadece bir sonraki dakikayı düşünün. Küçük adımlar yeterli.',
      psychologicalFunctions: ['öz-etkinlik', 'kontrol duygusu'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.hopelessness,
    ),
    PfaMessage(
      text: 'Hayatta olmanız ve mesaj atabilmeniz önemli. Bunu başarıyorsunuz.',
      psychologicalFunctions: ['öz-etkinlik', 'gerçekçi umut'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.hopelessness,
    ),
    PfaMessage(
      text:
          'Böyle anlarda umutsuzluk hissi doğal bir tepkidir. Bu duygu geçer; şu an güçlüsünüz.',
      psychologicalFunctions: ['duyguları normalleştirme', 'öz-etkinlik'],
      pfaComponent: 'Calming',
      category: PfaCategory.hopelessness,
    ),
    PfaMessage(
      text: 'Dışarıda ekipler çalışıyor. Durumunuz bilinmeye devam ediyor.',
      psychologicalFunctions: ['gerçekçi umut', 'güvenlik hissi'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.hopelessness,
    ),

    // ─── Yalnızlık ve Terk Edilmişlik ────────────────────────────────────
    PfaMessage(
      text:
          'Yalnız değilsiniz. Bu mesajı okuyorsanız sisteme bağlısınız ve bilgileriniz iletildi.',
      psychologicalFunctions: ['sosyal bağlılık', 'güvenlik hissi'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.loneliness,
    ),
    PfaMessage(
      text:
          'Sizi düşünen insanlar var. Şu an ulaşamasalar da varlığınızı biliyorlar.',
      psychologicalFunctions: ['sosyal bağlılık', 'duyguları normalleştirme'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.loneliness,
    ),
    PfaMessage(
      text: 'Bu sistem sayesinde sessiniz duyuluyor. Yalnız değilsiniz.',
      psychologicalFunctions: ['sosyal bağlılık', 'güvenlik ve görülme hissi'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.loneliness,
    ),
    PfaMessage(
      text:
          'Uzakta olsalar bile sevdikleriniz sizi arıyor. Sistemimiz konumunuzu paylaşıyor.',
      psychologicalFunctions: ['sosyal bağlılık', 'gerçekçi umut'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.loneliness,
      vulnerabilityPriority: 1,
    ),

    // ─── Şiddetli Ağrı veya Sıkışma ─────────────────────────────────────
    PfaMessage(
      text:
          'Ağrıyı biliyoruz. Mümkünse sakin tutun kendinizi — hareketsiz kalmak enerji korur.',
      psychologicalFunctions: ['güvenlik', 'öz-etkinlik'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.painTrapped,
    ),
    PfaMessage(
      text:
          'Sıkıştığınız yerde derin nefes almak oksijeni verimli kullanmanıza yardımcı olur.',
      psychologicalFunctions: ['öz-etkinlik', 'sakinleşme'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.painTrapped,
    ),
    PfaMessage(
      text: 'Durumunuz iletildi. Kurtarma ekipleri böyle durumlara hazırlıklı.',
      psychologicalFunctions: ['güvenlik hissi', 'gerçekçi umut'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.painTrapped,
    ),
    PfaMessage(
      text:
          'Ağrı ve korku aynı anda çok ağır gelebilir. Bunu hissetmeniz normaldir. Sizi duyan biri var.',
      psychologicalFunctions: ['duyguları normalleştirme', 'sosyal bağlılık'],
      pfaComponent: 'Calming',
      category: PfaCategory.painTrapped,
    ),
    PfaMessage(
      text:
          'Yanınızda biri varsa onun sesine odaklanın. Yalnızsanız nefesinize odaklanın.',
      psychologicalFunctions: ['sakinleşme', 'öz-etkinlik'],
      pfaComponent: 'Calming',
      category: PfaCategory.painTrapped,
    ),

    // ─── Bilgi Belirsizliği / Dışarıda Neler Olduğuna Dair Kaygı ────────
    PfaMessage(
      text:
          'Dışarıdaki durumu tam bilmemek zor. Şu an için en sağlıklısı güvenli kalmaya odaklanmak.',
      psychologicalFunctions: ['duyguları normalleştirme', 'öz-etkinlik'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.uncertainty,
    ),
    PfaMessage(
      text:
          'Belirsizlik kaygı yaratır; bu doğal. Kontrol edebildiğinize — nefesinize, pozisyonunuza — odaklanın.',
      psychologicalFunctions: ['duyguları normalleştirme', 'kontrol duygusu'],
      pfaComponent: 'Information on Coping',
      category: PfaCategory.uncertainty,
    ),
    PfaMessage(
      text: 'Bilgi geldikçe paylaşılacak. Şu an için konumunuz kayıt altında.',
      psychologicalFunctions: ['güvenlik hissi', 'gerçekçi umut'],
      pfaComponent: 'Safety and Comfort',
      category: PfaCategory.uncertainty,
    ),
    PfaMessage(
      text:
          'Sevdikleriniz hakkında bilgi şu an ulaşmıyor olabilir. Bu onların güvende olmadığı anlamına gelmez.',
      psychologicalFunctions: ['duyguları normalleştirme', 'gerçekçi umut'],
      pfaComponent: 'Calming',
      category: PfaCategory.uncertainty,
    ),
    PfaMessage(
      text: 'Dışarıda koordinasyon sürüyor. Sizi aramak için çalışan insanlar var.',
      psychologicalFunctions: ['gerçekçi umut', 'sosyal bağlılık'],
      pfaComponent: 'Social Connection',
      category: PfaCategory.uncertainty,
    ),
  ];

  static List<PfaMessage> forCategory(PfaCategory category) =>
      all.where((m) => m.category == category).toList();
}
