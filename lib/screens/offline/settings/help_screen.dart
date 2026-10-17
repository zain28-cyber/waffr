// In-app FAQ grouped by topic (balance, expenses, reports, savings, shopping,
// notifications, account, security). Opened from settings.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Expandable help sections with Arabic Q&A copy. The copy is a const list
/// of records inside [build]; edit it there.
class HelpScreen extends StatelessWidget {
  /// Creates a [HelpScreen].
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // FAQ content: one record per topic, each with its question/answer pairs.
    const sections =
        <({String title, List<({String question, String answer})> items})>[
          (
            title: 'الرصيد والدخل',
            items: [
              (
                question: 'كيف أضيف دخلاً إلى الرصيد؟',
                answer: 'من الشاشة الرئيسية اضغط «إضافة دخل»، ثم أدخل المبلغ. اختر «نوع الدخل»: «شهري» أو «مرة واحدة». إذا كان لديك رصيد حالياً يمكنك إبقاؤه أو نقله إلى التوفير. مصدر الدخل اختياري. ثم اضغط «حفظ الدخل». يُسجَّل الوقت حسب ساعة جهازك مباشرة، حتى لو لم يكن هناك اتصال.',
              ),
              (
                question: 'ماذا يعني «نوع الدخل» و«نقل الرصيد للتوفير»؟',
                answer: '«شهري» يربط هذا الدخل بالشهر الحالي. عند انتهاء الشهر ينقل وفّر ما تبقى منه، بعد المصروفات والتوفير الدوري، إلى التوفير. لا يُضاف دخل جديد تلقائياً. «مرة واحدة» لا يجري هذا النقل، ويناسب الدخل غير المنتظم. «نقل الرصيد للتوفير» ينقل رصيدك الحالي كله إلى التوفير قبل إضافة الدخل الجديد.',
              ),
              (
                question: 'كيف أحدد الدخل الشهري أو أغيّره أو أزيله؟',
                answer: 'من الإعدادات اضغط «الدخل الشهري». الخيار ظاهر حتى قبل أن تضبطه. أدخل المبلغ ثم «حفظ» لتحديده أو تغييره، أو «إزالة الدخل» لإلغائه بالكامل. الإزالة لا تحذف الدخل المسجّل سابقاً في السجل، لكنها توقف الخطط الدورية التي تعتمد على نسبة من الدخل إلى أن تعيد تحديده.',
              ),
              (
                question: 'كيف يُحسب الرصيد الحالي؟',
                answer: 'الرصيد الحالي هو مجموع الدخل المسجّل ناقص مجموع المصروفات وناقص المبلغ الموجود حالياً في التوفير. توفير مبلغ يقلّل الرصيد المتاح، وسحبه يعيده إليه.',
              ),
              (
                question: 'كيف أتراجع عن دخل سجّلته؟',
                answer: 'من بطاقة الرصيد في الشاشة الرئيسية اضغط أيقونة المدفوعات لفتح سجل الدخل. بجانب العملية اضغط أيقونة التراجع، ثم أكّد. يُحذف الدخل من السجل ويُخصم مبلغه من الرصيد، وينعكس ذلك على التقارير والمزامنة.',
              ),
            ],
          ),
          (
            title: 'المصروفات',
            items: [
              (
                question: 'كيف أسجّل مصروفاً؟',
                answer: 'من الشاشة الرئيسية اضغط «إضافة مصروف»، وأدخل المبلغ، ثم اختر التصنيف. يمكنك إضافة ملاحظة. لا يُحفظ المصروف إذا كان أكبر من الرصيد المتاح. الوقت المسجّل هو وقت جهازك لحظة الحفظ.',
              ),
              (
                question: 'كيف أستخدم المضاعف بجانب المبلغ؟',
                answer: 'بجانب المبلغ، في الجهة المقابلة لـ «ل.س» وبنفس حجمه، يوجد مضاعف يبدأ من ×1. اضغطه واختر قيمة مثل ×2 أو ×3. المبلغ المحفوظ هو ما كتبته مضروباً في هذه القيمة. عند ×1 يبقى المبلغ كما أدخلته.',
              ),
              (
                question: 'كيف أضيف تصنيفاً خاصاً؟',
                answer: 'داخل نافذة المصروف، في شبكة التصنيفات، اضغط «مخصص» ثم اختر اسماً وأيقونة. لتعديل تصنيف أضفته أو حذفه، اضغط عليه مطوّلاً.',
              ),
              (
                question: 'ما هي الالتزامات؟',
                answer: 'الالتزامات هي المصروفات التي تتكرر بانتظام، مثل الإيجار والاشتراكات والفواتير. لإضافة التزام اضغط «إضافة مصروف» واختر «مصروف متكرر»، ثم حدّد كل كم يوماً أو أسبوعاً أو شهراً يتكرر. تظهر التزاماتك في الشاشة الرئيسية داخل بطاقة «آخر المصروفات»: اسحب البطاقة جانباً لتنتقل إليها، واضغطها لفتح قسم الالتزامات.',
              ),
              (
                question: 'ما الفرق بين الخصم التلقائي والخصم بعد تأكيدي؟',
                answer: '«تلقائي»: يُخصم المبلغ من رصيدك في موعده دون أن نسألك، ويناسب من لديه راتب ثابت. إذا لم يكفِ الرصيد لا يُخصم، ويصلك تنبيه، ثم يُخصم عندما يتوفر الرصيد. «بعد تأكيدي»: عند حلول الموعد يصلك تنبيه، وتختار بنفسك خصم المبلغ أو تأجيله. يناسب من يكون دخله غير منتظم، مثل العمل الحر.',
              ),
              (
                question: 'كيف أؤجّل التزاماً، وماذا يحدث إذا تراكم؟',
                answer: 'في قائمة «التزامات بانتظار تأكيدك» اختر «تأجيل» ثم حدّد متى نذكّرك: بعد يوم أو 3 أيام أو أسبوع، أو عند إضافة دخل جديد. إذا حلّ موعد جديد قبل أن تخصم الدفعة السابقة، تتراكم الدفعات، ويمكنك خصم دفعة واحدة أو خصمها كلها. عند إضافة دخل جديد يعرض وفّر عليك مراجعة الالتزامات التي لم تُخصم بعد.',
              ),
              (
                question: 'كيف أعدّل التزاماً أو أوقفه؟',
                answer: 'افتح قسم الالتزامات من الشاشة الرئيسية أو من الإعدادات، ثم اضغط على الالتزام. يمكنك تغيير المبلغ أو طريقة الخصم، أو إيقافه مؤقتاً، أو حذفه. المصروفات التي خُصمت سابقاً تبقى في السجل.',
              ),
              (
                question: 'كيف أتراجع عن مصروف؟',
                answer: 'من شاشة التقارير اضغط «سجل المصروفات». بجانب المصروف اضغط أيقونة التراجع ثم أكّد. يُحذف من السجل ويعود مبلغه إلى الرصيد. إذا كان ناتجاً عن شراء من قائمة المشتريات، يعود ذلك العنصر غير مُشترى.',
              ),
              (
                question: 'أين أرى آخر مصروفاتي؟',
                answer: 'الشاشة الرئيسية تعرض آخر ثلاثة مصروفات. لعرض السجل كاملاً افتح التقارير ثم «سجل المصروفات».',
              ),
            ],
          ),
          (
            title: 'التقارير',
            items: [
              (
                question: 'كيف أقرأ التقارير؟',
                answer: 'افتح التقارير من رمز الرسم البياني في الشريط السفلي. اختر «اليوم» أو أسبوعاً أو شهراً أو 3 أشهر أو 6 أشهر أو سنة، واستخدم السهمين للتنقل بين الفترات. يعرض التقرير مجموع الصرف، وتوزيعه حسب التصنيف، ومقارنته بالفترة السابقة.',
              ),
              (
                question: 'ماذا يعرض تقرير اليوم؟',
                answer: 'تقرير «اليوم» يخص اليوم الحالي من منتصف الليل حتى نهايته، ويقسّم الرسم حسب الساعات. الساعة التي لا فيها مصروف تبقى فارغة على الرسم دون أن تعطّل العرض. عند لمس نقطة تظهر الساعة والمبلغ.',
              ),
            ],
          ),
          (
            title: 'التوفير والأهداف',
            items: [
              (
                question: 'كيف أوفّر مبلغاً أو أسحبه؟',
                answer: 'من شاشة التوفير اضغط «توفير مبلغ» لنقل مبلغ من الرصيد إلى التوفير، أو «سحب إلى الرصيد» لإعادته. لا يمكنك توفير أكثر من رصيدك المتاح، ولا سحب أكثر من المبلغ الموفَّر.',
              ),
              (
                question: 'كيف أنشئ هدف توفير؟',
                answer: 'من شاشة التوفير اضغط «إنشاء هدف». أدخل الاسم والمبلغ المستهدف، ثم اختر طريقة التوفير: نسبة من الدخل، أو مبلغاً ثابتاً كل شهر، أو مبلغاً مخصصاً توفّره بنفسك. مبلغ التوفير الشهري يقبل الأرقام الكبيرة مثل بقية مبالغ وفّر. راجع المعاينة ثم احفظ.',
              ),
              (
                question: 'لماذا لا أستطيع إنشاء خطة دورية؟',
                answer: 'الخطة الدورية تُحسب من الدخل الشهري. إذا لم تحدده بعد، يوضح وفّر ذلك ويمنع إنشاء الخطة. حدّد «الدخل الشهري» من الإعدادات أولاً. النسبة من الدخل والمبلغ الثابت في هدف التوفير يحتاجان الدخل الشهري أيضاً، أما «مبلغ مخصص» فيبقى متاحاً بدونه.',
              ),
              (
                question: 'كيف تعمل الخطة الدورية؟',
                answer: 'من شاشة التوفير اضغط «خطط التوفير». اختر نسبة التوفير والمدة، راجع المبلغ الدوري والمستهدف، ثم أكّد. عند اكتمال كل فترة ينقل وفّر مبلغ الخطة من الرصيد المتاح إلى التوفير، بحد ما يتوفر في الرصيد. إذا أزلت الدخل الشهري تتوقف الخطط المعتمدة على النسبة إلى أن تعيد تحديده.',
              ),
              (
                question: 'كيف يُحسب تقدّم الهدف، وكيف أحذفه؟',
                answer: 'التقدّم هو ما دخل إلى التوفير لهذا الهدف بعد إنشائه، بعد طرح ما سُحب. عند بلوغ المبلغ المستهدف يكتمل الهدف. الأهداف المكتملة في «الأهداف المحققة». من «إدارة الأهداف» يمكنك ترتيب الأهداف أو حذف هدف. حذف الهدف لا يسحب المال الموفَّر.',
              ),
            ],
          ),
          (
            title: 'التسوق',
            items: [
              (
                question: 'كيف أستخدم قائمة المشتريات؟',
                answer: 'من بطاقة الرصيد اضغط أيقونة القائمة، أو افتحها من شاشة التوفير. أضف ما تريد شراءه. عند تسجيل الشراء يُطلب السعر ويُنشأ مصروف عادي بالمبلغ والوقت الحالي على جهازك، ويظهر في السجل والرصيد. التراجع عن ذلك المصروف يعيد العنصر إلى القائمة.',
              ),
            ],
          ),
          (
            title: 'الإشعارات والوقت',
            items: [
              (
                question: 'كيف تعمل الإشعارات؟',
                answer: 'رمز الجرس أعلى الشاشة يعرض تنبيهات وفّر عن الرصيد والإنفاق والتوفير والأهداف والالتزامات. تنبيه الالتزام المستحق يفتح قائمة التأكيد مباشرة. يمكنك فتح تنبيه لتمييزه كمقروء، أو تعيين الكل كمقروء، أو مسح السجل. اضغط مطولاً على الجرس لكتم الإشعارات أو تفعيلها. عند كتم الإشعارات لا تُضاف تنبيهات جديدة.',
              ),
              (
                question: 'هل يعتمد وقت العمليات على الإنترنت؟',
                answer: 'لا. وقت المصروف والدخل والتوفير والشراء والموعد المتكرر هو وقت جهازك لحظة حدوثه. إذا سجّلت مصروفاً الساعة 6 مساءً دون اتصال، يبقى 6 مساءً حتى لو اتصل الجهاز لاحقاً. المزامنة لا تستبدل هذا الوقت بوقت وصول العملية إلى الخادم.',
              ),
            ],
          ),
          (
            title: 'الحساب والمظهر',
            items: [
              (
                question: 'كيف أسجّل الدخول أو أستخدم التطبيق دون حساب؟',
                answer: 'يمكنك استخدام وفّر على الجهاز دون حساب. من الإعدادات اضغط بطاقة الحساب لتسجيل الدخول أو إنشاء حساب. بعد تسجيل الدخول تُزامَن بياناتك عند توفر الاتصال. تسجيل الخروج يعيدك إلى شاشة الدخول وتبقى بياناتك على الجهاز، ويمكنك المتابعة كضيف.',
              ),
              (
                question: 'كيف أغيّر المظهر؟',
                answer: 'من الإعدادات استخدم «الوضع الداكن». العربية هي اللغة الوحيدة في هذه النسخة.',
              ),
            ],
          ),
          (
            title: 'الحماية والبيانات',
            items: [
              (
                question: 'كيف يعمل قفل التطبيق؟',
                answer: 'من الإعدادات فعّل «قفل التطبيق» ثم أكّد بهوية جهازك. وفّر لا ينشئ رمزاً خاصاً، بل يستخدم قفل الشاشة أو البصمة أو الوجه المعدّ على الجهاز. عند مغادرة التطبيق تُطلب المصادقة من جديد عبر «فتح القفل».',
              ),
              (
                question: 'ماذا لو لم تعمل البصمة؟',
                answer: 'تأكد من إعداد قفل الشاشة على جهازك. قد تسمح نافذة النظام برمز الجهاز أو نمطه. إذا ألغيت المحاولة ابقَ في شاشة القفل واضغط «فتح القفل» مرة أخرى. الأجهزة التي لا تدعم مصادقة الجهاز لا يمكن تفعيل القفل عليها.',
              ),
              (
                question: 'ماذا يحدث عند إعادة ضبط التطبيق؟',
                answer: 'بعد تأكيد حذف البيانات يمسح وفّر ما على هذا الجهاز: الملف، والدخل والمصروفات والتوفير والأهداف والالتزامات وقائمة المشتريات والإشعارات والمظهر وقفل التطبيق. لا يمكن التراجع. عند تسجيل الدخول قد تُستعاد النسخة المتزامنة مع الحساب، أما البيانات التي لم تُزامَن فتُحذف من الجهاز.',
              ),
            ],
          ),
        ];

    // Page: title, then each section heading followed by its questions.
    final palette = AppPalette.of(context);
    final bg = palette.background;
    final surface = palette.surface;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final accent = palette.accent;

    return Scaffold(
      backgroundColor: bg,
      appBar: WaffrBackHeader(title: 'المساعدة'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: staggered([
          Text(
            'دليل وفّر',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
            ),
          ),
          const SizedBox(height: 5),

          const SizedBox(height: 22),
          for (final section in sections) ...[
            Text(
              section.title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < section.items.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              _FAQItem(
                question: section.items[index].question,
                answer: section.items[index].answer,
                accent: accent,
                surface: surface,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ],
            const SizedBox(height: 22),
          ],
        ]),
      ),
    );
  }
}

/// One expandable FAQ question/answer pair.
class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  final Color accent;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _FAQItem({
    required this.question,
    required this.answer,
    required this.accent,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

/// State of [_FAQItem]. Tracks whether it is open, for the arrow icon.
class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Material (not a decorated box) so the tile paints on its own surface.
    return Material(
      color: widget.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(
            right: 16,
            left: 16,
            bottom: 16,
          ),
          trailing: Icon(
            _isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: widget.accent,
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          title: Text(
            widget.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.textPrimary,
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.answer,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: widget.textSecondary,
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
