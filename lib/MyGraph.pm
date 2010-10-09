package MyGraph;
use strict;
use constant PI => scalar(4 * atan2 1, 1);
use MyDb;
use GD::Graph::mixed;
use GD::SVG;
my $config;
sub new {
    my $class = shift;
    my %arg = @_;
    if (defined($arg{config})) {
	$config = $arg{config};
    }
    my $me = bless {}, $class;
    foreach my $key (%arg) {
	$me->{$key} = $arg{$key} if (defined($arg{$key}));
    }
    return ($me);
}

sub deg2rad {PI * $_[0] / 180}

sub Make_Landscape {
    my $me = shift;
    my $species = shift;
    my $accession = $me->{accession};
    my $filename = $me->Picture_Filename(type => 'landscape',);
    my $table = "landscape_$species";
    system("touch $filename");
    my $db = new PRFdb(config=>$config);
    my $data = $db->MySelect("SELECT start, algorithm, pairs, mfe FROM $table WHERE accession='$accession' ORDER BY start, algorithm");
    return(undef) if (!defined($data));
    my $slipsites = $db->MySelect("SELECT distinct(start) FROM mfe WHERE accession='$accession' ORDER BY start");
    my $start_stop = $db->MySelect("SELECT orf_start, orf_stop FROM genome WHERE accession = '$accession'");
    my $info = {};
    my @points = ();
    my ($mean_nupack, $mean_pknots, $mean_vienna) = 0;
    my $position_counter = 0;
    foreach my $datum (@{$data}) {
	$position_counter++;
	my $place = $datum->[0];
	push(@points, $place);
	
	if ($datum->[1] eq 'pknots') {
	    $info->{$place}->{pknots} = $datum->[3];
	    $mean_pknots = $mean_pknots + $datum->[3];
	} elsif ($datum->[1] eq 'nupack') {
	    $info->{$place}->{nupack} = $datum->[3];
	    $mean_nupack = $mean_nupack + $datum->[3];
	} elsif ($datum->[1] eq 'vienna') {
	    $info->{$place}->{vienna} = $datum->[3];
	    $mean_vienna = $mean_vienna + $datum->[3];
	}
    }    ## End foreach spot
    if ($position_counter == 0) {  ## There is no data!?
	return(undef);
	print STDERR "There is no data\n";
    }
    $position_counter = $position_counter / 3;
    $mean_pknots = $mean_pknots / $position_counter;
    $mean_nupack = $mean_nupack / $position_counter;
    $mean_vienna = $mean_vienna / $position_counter;
    my (@axis_x, @nupack_y, @pknots_y, @vienna_y, @m_nupack, @m_pknots, @m_vienna);
    my $end_spot = $points[$#points] + 105;
    my $current  = 0;
    while ($current <= $end_spot) {
	push(@axis_x, $current);
	push(@m_nupack, $mean_nupack);
	push(@m_pknots, $mean_pknots);
	push(@m_vienna, $mean_vienna);
	if (defined($info->{$current})) {
	    push(@nupack_y, $info->{$current}->{nupack});
	    push(@pknots_y, $info->{$current}->{pknots});
	    push(@vienna_y, $info->{$current}->{vienna});
	} else {
	    push(@nupack_y,undef);
	    push(@pknots_y,undef);
	    push(@vienna_y,undef);
	}
	$current++;
    }
    my @mfe_data = (\@axis_x, \@nupack_y, \@pknots_y, \@vienna_y, \@m_nupack, \@m_pknots, \@m_vienna);
    my $width = $end_spot;
    my $height = 400;
    my $graph = new GD::Graph::mixed($width,$height);
    $graph->set(bgclr => 'white', x_label => 'Distance on ORF', y_label => 'kcal/mol',
		y_label_skip => 2, y_number_format => "%.2f", x_labels_vertical => 1,
		x_label_skip => 100, line_width => 2, dclrs => [qw(blue red green blue red green)],
		default_type => 'lines', types => [qw(lines lines lines lines lines lines)],) or die $graph->error;
    $graph->set_legend_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_x_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_axis_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    $graph->set_y_label_font("$config->{base}/fonts/$config->{graph_font}", $config->{graph_font_size});
    my $gd = $graph->plot(\@mfe_data) or die($graph->error);
    
    my $axes_coords = $graph->get_feature_coordinates('axes');
    my $top_x_coord = $axes_coords->[1];
    my $top_y_coord = $axes_coords->[2];
    my $bottom_x_coord = $axes_coords->[3];
    my $bottom_y_coord = $axes_coords->[4];
    my $green = $gd->colorAllocate(0,191,0);
    my $red = $gd->colorAllocate(191,0,0);
    my $black = $gd->colorAllocate(0,0,0);
    my $start_x_coord = $top_x_coord + $start_stop->[0]->[0];
    my $stop_x_coord = $top_x_coord + $start_stop->[0]->[1];
    my $orf_start = 0;
    my $orf_stop = $end_spot;
    ## Fill in the start site:
    $gd->filledRectangle($start_x_coord, $bottom_y_coord+1, $start_x_coord+1, $top_y_coord-1, $green);
    $gd->filledRectangle($stop_x_coord, $bottom_y_coord+1, $stop_x_coord+1, $top_y_coord-1, $red);
    foreach my $slipsite_x_coords (@{$slipsites}) {
	my $slipsite_x_coord = $slipsite_x_coords->[0];
	$gd->filledRectangle($slipsite_x_coord, $bottom_y_coord+1, $slipsite_x_coord+1, $top_y_coord-1, $black);
    }

    open(IMG, ">$filename") or die $!;
    binmode IMG;
    print IMG $gd->png;
    close IMG;
    my $ret = {
	filename => $filename,
	mean_pknots => $mean_pknots,
	mean_nupack => $mean_nupack,
	mean_vienna => $mean_vienna,
	height => $height,
	width => $width,
    };
    return ($ret);
}

1;
