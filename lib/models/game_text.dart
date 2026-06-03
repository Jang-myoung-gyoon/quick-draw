import 'upgrade.dart';

enum GameLanguage { ko, en }

class GameText {
  final GameLanguage language;

  const GameText(this.language);

  bool get isKo => language == GameLanguage.ko;

  String get appTitle => isKo ? '발도술 키우기' : 'Battoujutsu Slasher';
  String get gameStart => isKo ? '게임 시작' : 'GAME START';
  String get achievements => isKo ? '업적' : 'ACHIEVEMENTS';
  String get ranking => isKo ? '랭킹' : 'RANKING';
  String get scoreRanking => isKo ? '스코어 랭킹' : 'SCORE';
  String get achievementRanking => isKo ? '업적 점수' : 'ACHIEVEMENT';
  String get noRankingRecords =>
      isKo ? '아직 기록이 없습니다.' : 'No score records yet.';
  String get friendCode => isKo ? '내 친구 코드' : 'MY FRIEND CODE';
  String get friendUidHint => isKo ? '친구 UID 입력' : 'Friend UID';
  String get addFriend => isKo ? '친구 추가' : 'ADD';
  String get refresh => isKo ? '새로고침' : 'Refresh';
  String get refreshLimited => isKo
      ? '친구 랭킹은 20분에 한 번 갱신됩니다.'
      : 'Friend rankings refresh every 20 minutes.';
  String get rankingServerUnavailable => isKo
      ? '서버 통신 실패: 로컬 데이터만 표시합니다.'
      : 'Server unavailable: showing local data only.';
  String get achievementConfirm => isKo ? '확인' : 'CLAIM';
  String get upgrades => isKo ? '업그레이드' : 'UPGRADES';
  String get stageLevel => isKo ? '스테이지 레벨' : 'STAGE LEVEL';
  String get characterLevel => isKo ? '캐릭터 레벨' : 'CHARACTER LEVEL';
  String get score => isKo ? '점수' : 'SCORE';
  String get defeated => isKo ? '패배' : 'DEFEATED';
  String get finalScore => isKo ? '최종 점수' : 'FINAL SCORE';
  String get bestScore => isKo ? '최고 점수' : 'BEST SCORE';
  String get finalReport => isKo ? '최종 리포트' : 'FINAL REPORT';
  String get tryAgain => isKo ? '다시 도전' : 'TRY AGAIN';
  String get shareLink => isKo ? '링크 공유' : 'SHARE LINK';
  String get upgrade => isKo ? '강화 선택' : 'UPGRADE';
  String get rare => isKo ? '레어' : 'RARE';
  String get settings => isKo ? '설정' : 'SETTINGS';
  String get close => isKo ? '닫기' : 'Close';
  String get master => isKo ? '마스터' : 'MASTER';
  String get bgm => isKo ? '배경음' : 'BGM';
  String get sfx => isKo ? '효과음' : 'SFX';
  String get home => isKo ? '홈으로' : 'HOME';
  String get languageLabel => isKo ? '언어' : 'LANGUAGE';
  String get korean => isKo ? '한국어' : 'Korean';
  String get english => isKo ? '영어' : 'English';
  String get energy => isKo ? '에너지' : 'ENERGY';
  String get step => isKo ? '경공' : 'STEP';
  String get current => isKo ? '현재' : 'CURRENT';
  String get characterLevelUp => isKo ? '캐릭터 레벨 업' : 'CHARACTER LEVEL UP';
  String get stageLevelUp => isKo ? '스테이지 레벨 업' : 'STAGE LEVEL UP';
  String level(int level) => isKo ? '레벨 $level' : 'LEVEL $level';
  String comboSlices(int combo) => isKo ? '$combo 연속 베기' : '$combo SLICES';
  String characterGauge(int level) => isKo ? '캐릭터 $level' : 'C.$level';
  String achievementUnlocked(String title) =>
      isKo ? '업적 달성: $title' : 'ACHIEVEMENT UNLOCKED: $title';

  String levelUpTitle(String title) {
    return switch (title) {
      'CHARACTER LEVEL UP' => characterLevelUp,
      'STAGE LEVEL UP' => stageLevelUp,
      _ => title,
    };
  }

  String upgradeTitle(UpgradeType type) => switch (type) {
    UpgradeType.bladePower => isKo ? '검기 강화' : 'Blade Power',
    UpgradeType.criticalStrike => isKo ? '치명 발도' : 'Critical Draw',
    UpgradeType.chainLength => isKo ? '연속 베기' : 'Longer Chain',
    UpgradeType.scrollRecovery => isKo ? '공중 흐름' : 'Aerial Flow',
    UpgradeType.energyEfficiency => isKo ? '고요한 호흡' : 'Calm Breathing',
    UpgradeType.focusTime => isKo ? '집중 시간' : 'Focus Window',
    UpgradeType.luck => isKo ? '행운' : 'Luck',
    UpgradeType.shadowClone => isKo ? '분신술' : 'Shadow Clone',
    UpgradeType.shield => isKo ? '수호 부적' : 'Guard Seal',
    UpgradeType.lightfootGauge => isKo ? '경공술' : 'Lightfoot',
    UpgradeType.chainStrike => isKo ? '연쇄 타격' : 'Chain Strike',
  };

  String upgradeDescription(UpgradeType type) => switch (type) {
    UpgradeType.bladePower =>
      isKo ? '공격력이 1 증가합니다.' : 'Increase attack power by 1.',
    UpgradeType.criticalStrike =>
      isKo ? '15% 확률로 2배 피해를 줍니다.' : 'Add +15% chance to deal double damage.',
    UpgradeType.chainLength =>
      isKo ? '베기 경로를 하나 더 입력할 수 있습니다.' : 'Add one more slash waypoint.',
    UpgradeType.scrollRecovery =>
      isKo ? '위로 스크롤할 때 에너지를 더 얻습니다.' : 'Gain more energy from upward scroll.',
    UpgradeType.energyEfficiency =>
      isKo ? '자유낙하 중 에너지 소모가 줄어듭니다.' : 'Slow passive energy drain.',
    UpgradeType.focusTime =>
      isKo ? '연속 베기 입력 시간이 늘어납니다.' : 'More time to finish a chain.',
    UpgradeType.luck =>
      isKo
          ? '보너스 오브젝트 등장 간격이 10% 줄어듭니다.'
          : 'Reduce the bonus object spawn interval by 10%.',
    UpgradeType.shadowClone =>
      isKo
          ? '분신을 하나 추가해 베기 범위를 넓힙니다.'
          : 'Add one side clone to widen slash range.',
    UpgradeType.shield =>
      isKo ? '충돌 피해를 한 번 막습니다.' : 'Block one collision hit.',
    UpgradeType.lightfootGauge =>
      isKo ? '이동으로 필살기 게이지를 채웁니다.' : 'Movement fills an ultimate gauge.',
    UpgradeType.chainStrike =>
      isKo
          ? '50% 확률로 피해를 입은 대상을 다음 베기 위치로 튕깁니다.'
          : '50% chance to bounce damaged targets into the next cut.',
  };

  String selectedAchievementTitle(UpgradeType type) =>
      isKo ? '${upgradeTitle(type)} 획득' : '${upgradeTitle(type)} Selected';
  String masteredAchievementTitle(UpgradeType type) =>
      isKo ? '${upgradeTitle(type)} 완성' : '${upgradeTitle(type)} Mastered';
  String get selectedAchievementDescription =>
      isKo ? '이 업그레이드를 처음 선택합니다.' : 'Choose this upgrade for the first time.';
  String get masteredAchievementDescription => isKo
      ? '이 업그레이드를 최대치까지 성장시킵니다.'
      : 'Reach the maximum state for this upgrade.';
  String stageAchievementTitle(int level) =>
      isKo ? '스테이지 $level 도달' : 'Stage $level Reached';
  String stageAchievementDescription(int level) =>
      isKo ? '스테이지 레벨 $level에 도달합니다.' : 'Reach stage level $level.';
  String characterAchievementTitle(int level) =>
      isKo ? '캐릭터 레벨 $level' : 'Character Level $level';
  String characterAchievementDescription(int level) => isKo
      ? '캐릭터를 레벨 $level까지 성장시킵니다.'
      : 'Raise the character to level $level.';
  String scoreAchievementTitle(int scoreTarget) =>
      isKo ? '$scoreTarget점 달성' : '$scoreTarget Score';
  String scoreAchievementDescription(int scoreTarget) =>
      isKo ? '$scoreTarget점을 달성합니다.' : 'Reach a score of $scoreTarget.';
}
