/// ===========================================================================
/// THE COUNTRIES LOCKINPOINT SERVES
///
/// One list. It used to live privately inside the signup screen, which is why
/// the profile could only ever print the stored code — a student who signed up
/// from Accra saw "GH" on their own profile, a database value shown to a
/// human. Naming a country is not signup's private business.
/// ===========================================================================
typedef LipCountry = ({String code, String name, String dial, String flag});

const kCountries = <LipCountry>[
  (code: 'NG', name: 'Nigeria', dial: '+234', flag: '🇳🇬'),
  (code: 'GH', name: 'Ghana', dial: '+233', flag: '🇬🇭'),
  (code: 'SL', name: 'Sierra Leone', dial: '+232', flag: '🇸🇱'),
  (code: 'LR', name: 'Liberia', dial: '+231', flag: '🇱🇷'),
  (code: 'GM', name: 'The Gambia', dial: '+220', flag: '🇬🇲'),
];

/// The country for a stored code, or null when the code is one this build does
/// not know. Null rather than a guess: printing "Nigeria" for an unrecognised
/// code would be worse than printing the code itself.
LipCountry? countryOf(String? code) {
  if (code == null || code.isEmpty) return null;
  final want = code.toUpperCase();
  for (final c in kCountries) {
    if (c.code == want) return c;
  }
  return null;
}

/// What a person should read: "🇳🇬 Nigeria" when we know the country, and the
/// raw code only when we genuinely do not.
String countryLabel(String? code) {
  final c = countryOf(code);
  if (c == null) return (code == null || code.isEmpty) ? '·' : code;
  return '${c.flag}  ${c.name}';
}

/// The dial code for a country, defaulting to Nigeria's — the app's home
/// market and the only sensible fallback for a phone box that must show
/// something.
String dialOf(String? code) => countryOf(code)?.dial ?? kCountries.first.dial;
