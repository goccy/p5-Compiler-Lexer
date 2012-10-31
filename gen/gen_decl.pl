use JSON qw/encode_json decode_json/;
use Data::Dumper;
open(ins, "<", "gen/decl.json");
open(ous, ">", "include/gen_token.hpp");
my $json_data;
foreach (<ins>) {
	$json_data .= $_;
}
my $data = decode_json($json_data);
my @array = @{$data};
my @token_enum = ();
my @kind_enum = ();
foreach my $elem (@array) {
	my $type = $elem->{type};
	my $kind = $elem->{kind};
	unless (grep{$_ eq $type} @token_enum) {
		push(@token_enum, $type);
	}
	unless (grep{$_ eq $kind} @kind_enum) {
		push(@kind_enum, $kind) if ($kind);
	}
}

print ous "namespace Enum {\n";
print ous "namespace Lexer {\n";
print ous "namespace Token {\n";
print ous "typedef enum {\n";
foreach (@token_enum) {
	print ous "\t$_,\n";
}
print ous "} Type;\n";
print ous "}\n";
print ous "\n";

print ous "typedef enum {\n";
foreach (@kind_enum) {
	print ous "\t$_,\n";
}
print ous "} Kind;\n";
print ous "}\n";
print ous "}\n";

open(ous, ">", "gen_token_decl.cpp");
print ous "#include <lexer.hpp>\n";
print ous "TokenInfo decl_tokens[] = {\n";
foreach my $elem (@array) {
	my $type = $elem->{type};
    my $kind = $elem->{kind};
    my $data = $elem->{data};
	print ous "\t{Enum::Lexer::Token::${type}, Enum::Lexer::${kind}, \"${type}\", \"${data}\"},\n";
}
print ous "};\n";
print ous "\n";
