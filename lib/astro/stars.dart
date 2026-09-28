import 'astro_math.dart';

class Star {
  final String name;
  final double ra; // J2000, degrees
  final double dec; // J2000, degrees
  final double mag;
  const Star(this.name, this.ra, this.dec, this.mag);
}

Star _s(String name, int rh, int rm, double rs, int sign, int dd, int dm, double ds, double mag) =>
    Star(name, hmsToDeg(rh, rm, rs), dmsToDeg(sign, dd, dm, ds), mag);

/// Bright-star catalog (J2000). Roughly the ~90 brightest named stars plus the
/// stars needed to draw the classic constellation figures below.
final List<Star> brightStars = [
  _s('Sirius', 6, 45, 8.9, -1, 16, 42, 58, -1.46),
  _s('Canopus', 6, 23, 57.1, -1, 52, 41, 44, -0.74),
  _s('Rigil Kentaurus', 14, 39, 36.5, -1, 60, 50, 2, -0.27),
  _s('Arcturus', 14, 15, 39.7, 1, 19, 10, 57, -0.05),
  _s('Vega', 18, 36, 56.3, 1, 38, 47, 1, 0.03),
  _s('Capella', 5, 16, 41.4, 1, 45, 59, 53, 0.08),
  _s('Rigel', 5, 14, 32.3, -1, 8, 12, 6, 0.13),
  _s('Procyon', 7, 39, 18.1, 1, 5, 13, 30, 0.34),
  _s('Achernar', 1, 37, 42.8, -1, 57, 14, 12, 0.46),
  _s('Betelgeuse', 5, 55, 10.3, 1, 7, 24, 25, 0.50),
  _s('Hadar', 14, 3, 49.4, -1, 60, 22, 23, 0.61),
  _s('Altair', 19, 50, 47.0, 1, 8, 52, 6, 0.76),
  _s('Acrux', 12, 26, 35.9, -1, 63, 5, 57, 0.76),
  _s('Aldebaran', 4, 35, 55.2, 1, 16, 30, 33, 0.86),
  _s('Antares', 16, 29, 24.5, -1, 26, 25, 55, 0.96),
  _s('Spica', 13, 25, 11.6, -1, 11, 9, 41, 0.97),
  _s('Pollux', 7, 45, 18.9, 1, 28, 1, 34, 1.14),
  _s('Fomalhaut', 22, 57, 39.0, -1, 29, 37, 20, 1.16),
  _s('Deneb', 20, 41, 25.9, 1, 45, 16, 49, 1.25),
  _s('Mimosa', 12, 47, 43.3, -1, 59, 41, 19, 1.25),
  _s('Regulus', 10, 8, 22.3, 1, 11, 58, 2, 1.35),
  _s('Adhara', 6, 58, 37.5, -1, 28, 58, 20, 1.50),
  _s('Castor', 7, 34, 36.0, 1, 31, 53, 18, 1.58),
  _s('Shaula', 17, 33, 36.5, -1, 37, 6, 14, 1.62),
  _s('Gacrux', 12, 31, 9.9, -1, 57, 6, 48, 1.63),
  _s('Bellatrix', 5, 25, 7.9, 1, 6, 20, 59, 1.64),
  _s('Elnath', 5, 26, 17.5, 1, 28, 36, 27, 1.65),
  _s('Miaplacidus', 9, 13, 12.0, -1, 69, 43, 2, 1.67),
  _s('Alnilam', 5, 36, 12.8, -1, 1, 12, 7, 1.69),
  _s('Alnair', 22, 8, 14.0, -1, 46, 57, 40, 1.73),
  _s('Alnitak', 5, 40, 45.5, -1, 1, 56, 34, 1.77),
  _s('Alioth', 12, 54, 1.7, 1, 55, 57, 35, 1.77),
  _s('Dubhe', 11, 3, 43.7, 1, 61, 45, 3, 1.79),
  _s('Mirfak', 3, 24, 19.4, 1, 49, 51, 40, 1.79),
  _s('Wezen', 7, 8, 23.5, -1, 26, 23, 36, 1.83),
  _s('Kaus Australis', 18, 24, 10.3, -1, 34, 23, 5, 1.85),
  _s('Avior', 8, 22, 30.8, -1, 59, 30, 34, 1.86),
  _s('Alkaid', 13, 47, 32.4, 1, 49, 18, 48, 1.86),
  _s('Sargas', 17, 37, 19.1, -1, 42, 59, 52, 1.87),
  _s('Menkalinan', 5, 59, 31.7, 1, 44, 56, 51, 1.90),
  _s('Atria', 16, 48, 39.9, -1, 69, 1, 40, 1.91),
  _s('Alhena', 6, 37, 42.7, 1, 16, 23, 57, 1.92),
  _s('Peacock', 20, 25, 38.9, -1, 56, 44, 6, 1.94),
  _s('Polaris', 2, 31, 49.1, 1, 89, 15, 51, 1.98),
  _s('Mirzam', 6, 22, 42.0, -1, 17, 57, 21, 1.98),
  _s('Alphard', 9, 27, 35.2, -1, 8, 39, 31, 1.98),
  _s('Hamal', 2, 7, 10.4, 1, 23, 27, 45, 2.00),
  _s('Nunki', 18, 55, 15.9, -1, 26, 17, 48, 2.05),
  _s('Menkent', 14, 6, 41.0, -1, 36, 22, 12, 2.06),
  _s('Alpheratz', 0, 8, 23.3, 1, 29, 5, 26, 2.06),
  _s('Mirach', 1, 9, 43.9, 1, 35, 37, 14, 2.07),
  _s('Rasalhague', 17, 34, 56.1, 1, 12, 33, 36, 2.07),
  _s('Kochab', 14, 50, 42.3, 1, 74, 9, 20, 2.08),
  _s('Saiph', 5, 47, 45.4, -1, 9, 40, 11, 2.09),
  _s('Algol', 3, 8, 10.1, 1, 40, 57, 20, 2.09),
  _s('Denebola', 11, 49, 3.6, 1, 14, 34, 19, 2.13),
  _s('Almach', 2, 3, 54.0, 1, 42, 19, 47, 2.10),
  _s('Diphda', 0, 43, 35.4, -1, 17, 59, 12, 2.04),
  _s('Mizar', 13, 23, 55.5, 1, 54, 55, 31, 2.23),
  _s('Schedar', 0, 40, 30.4, 1, 56, 32, 14, 2.24),
  _s('Eltanin', 17, 56, 36.4, 1, 51, 29, 20, 2.24),
  _s('Sadr', 20, 22, 13.7, 1, 40, 15, 24, 2.23),
  _s('Mintaka', 5, 32, 0.4, -1, 0, 17, 57, 2.23),
  _s('Caph', 0, 9, 10.7, 1, 59, 8, 59, 2.28),
  _s('Merak', 11, 1, 50.5, 1, 56, 22, 57, 2.37),
  _s('Enif', 21, 44, 11.2, 1, 9, 52, 30, 2.39),
  _s('Scheat', 23, 3, 46.5, 1, 28, 4, 58, 2.42),
  _s('Phecda', 11, 53, 49.8, 1, 53, 41, 41, 2.44),
  _s('Navi', 0, 56, 42.5, 1, 60, 43, 0, 2.47),
  _s('Markab', 23, 4, 45.7, 1, 15, 12, 19, 2.48),
  _s('Menkar', 3, 2, 16.8, 1, 4, 5, 23, 2.54),
  _s('Zosma', 11, 14, 6.5, 1, 20, 31, 25, 2.56),
  _s('Algieba', 10, 19, 58.4, 1, 19, 50, 29, 2.01),
  _s('Unukalhai', 15, 44, 16.1, 1, 6, 25, 32, 2.63),
  _s('Ruchbah', 1, 25, 49.0, 1, 60, 14, 7, 2.68),
  _s('Zubeneschamali', 15, 17, 0.4, -1, 9, 22, 59, 2.61),
  _s('Algenib', 0, 13, 14.2, 1, 15, 11, 1, 2.83),
  _s('Vindemiatrix', 13, 2, 10.6, 1, 10, 57, 33, 2.83),
  _s('Albireo', 19, 30, 43.3, 1, 27, 57, 35, 3.05),
  _s('Megrez', 12, 15, 25.6, 1, 57, 1, 57, 3.31),
  _s('Segin', 1, 54, 23.7, 1, 63, 40, 12, 3.37),
  _s('Gienah Cygni', 20, 46, 12.7, 1, 33, 58, 13, 2.48),
  _s('Fawaris', 19, 44, 58.5, 1, 45, 7, 51, 2.87),
  _s('Dschubba', 16, 0, 20.0, -1, 22, 37, 18, 2.29),
  _s('Acrab', 16, 5, 26.2, -1, 19, 48, 19, 2.62),
  _s('Larawag', 16, 50, 9.8, -1, 34, 17, 36, 2.29),
  _s('Imai', 12, 15, 8.7, -1, 58, 44, 56, 2.79),
  _s('Tarazed', 19, 46, 15.6, 1, 10, 36, 48, 2.72),
  _s('Alshain', 19, 55, 18.8, 1, 6, 24, 24, 3.71),
  _s('Sheliak', 18, 50, 4.8, 1, 33, 21, 46, 3.52),
  _s('Sulafat', 18, 58, 56.6, 1, 32, 41, 22, 3.25),
  _s('Tejat', 6, 22, 57.6, 1, 22, 30, 49, 2.87),
  _s('Mebsuta', 6, 43, 55.9, 1, 25, 7, 52, 3.06),
  _s('Alcyone', 3, 47, 29.1, 1, 24, 6, 18, 2.87),
];

/// Constellation stick figures, as pairs of star names from [brightStars].
const List<List<String>> constellationLines = [
  // Orion
  ['Betelgeuse', 'Bellatrix'], ['Betelgeuse', 'Alnitak'], ['Bellatrix', 'Mintaka'],
  ['Mintaka', 'Alnilam'], ['Alnilam', 'Alnitak'], ['Alnitak', 'Saiph'], ['Mintaka', 'Rigel'],
  // Ursa Major (Big Dipper)
  ['Dubhe', 'Merak'], ['Merak', 'Phecda'], ['Phecda', 'Megrez'], ['Megrez', 'Dubhe'],
  ['Megrez', 'Alioth'], ['Alioth', 'Mizar'], ['Mizar', 'Alkaid'],
  // Cassiopeia
  ['Caph', 'Schedar'], ['Schedar', 'Navi'], ['Navi', 'Ruchbah'], ['Ruchbah', 'Segin'],
  // Cygnus (Northern Cross)
  ['Deneb', 'Sadr'], ['Sadr', 'Albireo'], ['Gienah Cygni', 'Sadr'], ['Sadr', 'Fawaris'],
  // Lyra
  ['Vega', 'Sheliak'], ['Sheliak', 'Sulafat'], ['Sulafat', 'Vega'],
  // Aquila
  ['Tarazed', 'Altair'], ['Altair', 'Alshain'],
  // Summer Triangle
  ['Vega', 'Deneb'], ['Deneb', 'Altair'], ['Altair', 'Vega'],
  // Scorpius (partial)
  ['Acrab', 'Dschubba'], ['Dschubba', 'Antares'], ['Antares', 'Larawag'],
  ['Larawag', 'Sargas'], ['Sargas', 'Shaula'],
  // Crux
  ['Acrux', 'Gacrux'], ['Mimosa', 'Imai'],
  // Leo
  ['Regulus', 'Algieba'], ['Algieba', 'Zosma'], ['Zosma', 'Denebola'], ['Regulus', 'Denebola'],
  // Gemini
  ['Castor', 'Pollux'], ['Castor', 'Mebsuta'], ['Pollux', 'Alhena'], ['Mebsuta', 'Tejat'],
  // Pegasus / Andromeda (Great Square)
  ['Alpheratz', 'Scheat'], ['Scheat', 'Markab'], ['Markab', 'Algenib'], ['Algenib', 'Alpheratz'],
  ['Alpheratz', 'Mirach'], ['Mirach', 'Almach'], ['Markab', 'Enif'],
  // Canis Major
  ['Sirius', 'Mirzam'], ['Sirius', 'Adhara'], ['Adhara', 'Wezen'],
  // Auriga
  ['Capella', 'Menkalinan'], ['Capella', 'Elnath'],
  // Taurus hint
  ['Aldebaran', 'Elnath'], ['Aldebaran', 'Alcyone'],
];

final Map<String, Star> starsByName = {for (final s in brightStars) s.name: s};
