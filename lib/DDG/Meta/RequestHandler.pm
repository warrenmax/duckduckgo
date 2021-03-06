package DDG::Meta::RequestHandler;

use strict;
use warnings;
use Carp;
require Moo::Role;

my @request_attributes = qw(

	query_raw
	query_nowhitespace
	query_nowhitespace_nodash
	query
	query_lc
	query_clean
	words
	wordcount
	triggers

);

my $default_handler = 'query_raw';

sub apply_keywords {
	my ( $class, $target, $result_handler ) = @_;
	
	{
		no strict "refs";

		*{"${target}::handle"} = sub {
			my $handler = shift;
			my $code;
			if (ref $handler eq 'CODE') {
				$code = $handler;
				$handler = $default_handler;
			} else {
				$code = shift;
				croak "We need a CODEREF for the handler" unless ref $code eq 'CODE';
			}
			my $block = $target->can('has_words')
				? $target->has_words
					? 'words'
					: $target->has_regexps
						? 'regexp'
						: croak "Please define words or regexp before you define a handler"
				: '';
			if (grep { $_ eq $handler } @request_attributes) {
				*{"${target}::handle_request_matches"} = sub {
					my ( $self, $request ) = @_;
					my @result;
					for ($request->$handler) {
						@result = $code->($_);
					}
					return @result ? $result_handler->($self,@result) : ();
				};
			} elsif ($handler eq 'request') {
				*{"${target}::handle_request_matches"} = sub {
					my ( $self, $request ) = @_;
					my @result;
					for ($request) {
						@result = $code->($_);
					}
					return @result ? $result_handler->($self,@result) : ();
				};
			} elsif ($handler eq 'remainder' || $handler eq 'remainder_lc') {
				croak "You must be using words matching for remainder handler" if !$block or $block eq 'regexp';
				*{"${target}::handle_request_matches"} = sub {
					my ( $self, $request, $pos ) = @_;
					my $remainder = $request->generate_remainder($pos);
					my @result;
					for ($handler eq 'remainder' ? $remainder : lc($remainder)) {
						@result = $code->($_);
					}
					return @result ? $result_handler->($self, @result) : ();
				};
			} elsif ($handler eq 'matches') {
				croak "You must be using regexps matching for matches handler" if !$block or $block eq 'words';
				*{"${target}::handle_request_matches"} = sub {
					my ( $self, $request, @matches ) = @_;
					my @result;
					for ($request->query_raw) {
						@result = $code->(@matches);
					}
					return @result ? $result_handler->($self,@result) : ();
				};
			} elsif ($handler eq 'all') {
				*{"${target}::handle_request_matches"} = sub {
					my ( $self, $request, @matches_or_pos ) = @_;
					my @result = $code->($self,$request,\@matches_or_pos);
					return @result ? $result_handler->($self,@result) : ();
				};
			} else {
				croak "I dont know how to handle ".$handler."!";
			}
		};
	}

}

1;
